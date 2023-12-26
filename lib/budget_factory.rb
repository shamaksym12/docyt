# frozen_string_literal: true

class BudgetFactory < BaseService
  attr_accessor :budget

  def create(current_user:, report_service:, params:)
    @budget = Budget.create!(
      report_service: report_service,
      year: params[:year],
      name: params[:name],
      creator_id: current_user.id,
      created_at: Time.zone.now,
      total_amount: 0.0
    )
    create_budget_items(report_service: report_service)
  end

  private

  def create_budget_items(report_service:)
    fetch_business_chart_of_accounts_by_params(business_id: report_service.business_id, display_name: '', acc_type: 'profit_loss')
    create_budget_items_with_standard_metrics
    create_budget_items_with_chart_of_accounts
    @budget.save!
  end

  def create_budget_items_with_standard_metrics
    StandardMetric.all.each_with_index do |metric, index|
      @budget.actual_budget_items.create!(chart_of_account_id: nil, accounting_class_id: nil, standard_metric_id: metric._id.to_s, position: index)
      @budget.draft_budget_items.create!(chart_of_account_id: nil, accounting_class_id: nil, standard_metric_id: metric._id.to_s, position: index)
    end
  end

  def create_budget_items_with_chart_of_accounts # rubocop:disable Metrics/MethodLength
    current_position = @budget.actual_budget_items.count
    leaf_business_chart_of_accounts.each do |business_chart_of_account|
      mapped_class_ids = business_chart_of_account.mapped_class_ids
      mapped_class_ids += [nil] if business_chart_of_account.mapped_class_ids.blank?
      mapped_class_ids.each do |class_id|
        @budget.actual_budget_items.create!(
          chart_of_account_id: business_chart_of_account.chart_of_account_id,
          accounting_class_id: class_id, standard_metric_id: nil, position: current_position
        )
        @budget.draft_budget_items.create!(
          chart_of_account_id: business_chart_of_account.chart_of_account_id,
          accounting_class_id: class_id, standard_metric_id: nil, position: current_position
        )
        current_position += 1
      end
    end
  end

  def leaf_business_chart_of_accounts
    @business_chart_of_accounts.reject do |bcoa|
      @business_chart_of_accounts.any? { |origin| origin.parent_id == bcoa.chart_of_account_id }
    end
  end
end
