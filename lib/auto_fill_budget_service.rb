# frozen_string_literal: true

class AutoFillBudgetService < BaseService
  attr_reader :budget, :report_service, :params

  def initialize(budget:, params:)
    super()
    @budget = budget
    @report_service = budget.report_service
    @params = params
    fetch_business_information(@report_service)
  end

  def perform
    general_ledgers = general_ledgers_for_full_year
    params[:budget_item_ids].each do |budget_item_id|
      budget_item = budget.draft_budget_items.find(budget_item_id)
      budget_item_values = create_budget_item_values(budget_item, general_ledgers)
      BudgetItemValueFactory.upsert_batch(budget_item: budget_item, budget_item_values: budget_item_values)
    end
    budget.status = Budget::STATE_DRAFT unless budget.status == Budget::STATE_DRAFT
    budget.save!
  end

  private

  def general_ledgers_for_full_year # rubocop:disable Metrics/MethodLength
    year = params[:year]
    general_ledgers = params[:months].map do |month|
      start_date = Date.new(year.to_i, month, 1)
      end_date = Date.new(year.to_i, month, -1)
      general_ledger = Quickbooks::CommonGeneralLedger.find_by(
        report_service: report_service, start_date: start_date, end_date: end_date
      )
      if general_ledger.blank?
        general_ledger = generate_general_ledger(
          report_service: report_service,
          start_date: start_date,
          end_date: end_date
        )
      end
      general_ledger
    end
    general_ledgers.compact
  end

  def generate_general_ledger(report_service:, start_date:, end_date:)
    qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
    return nil if qbo_authorization.nil?

    import_result = Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::CommonGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
    import_result.general_ledger
  end

  def create_budget_item_values(budget_item, general_ledgers) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize
    budget_item_values = [*1..12].map { |month| { month: month, value: 0 } }
    return budget_item_values if params[:clear].present?

    budget_item_values = budget_item.budget_item_values.map { |a| { month: a.month, value: a.value } } if budget_item.budget_item_values.present?

    if budget_item.standard_metric_id.present?
      year = params[:year]
      metrics_service_value_api_instance = MetricsServiceClient::ValueApi.new
      standard_metric = StandardMetric.find(budget_item.standard_metric_id)
      params[:months].each do |month|
        response = metrics_service_value_api_instance.get_metric_value(
          @report_service.business_id,
          standard_metric.code,
          Date.new(year.to_i, month, 1).to_s,
          Date.new(year.to_i, month, -1).to_s
        )
        budget_item_values[month - 1][:value] = response.value * params[:increase]
      end
    else
      biz_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == budget_item.chart_of_account_id }
      accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == budget_item.accounting_class_id }
      general_ledgers.each do |general_ledger|
        line_item_details = general_ledger.line_item_details.where(chart_of_account_qbo_id: biz_chart_of_account.qbo_id)
        line_item_details = line_item_details.where(accounting_class_qbo_id: accounting_class.external_id) if accounting_class.present?
        value = line_item_details.sum(:amount)
        budget_item_values[general_ledger.start_date.month - 1][:value] = value * params[:increase]
      end
    end
    budget_item_values
  end
end
