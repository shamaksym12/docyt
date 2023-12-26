# frozen_string_literal: true

class ProfitAndLossReportFactory < ReportFactory # rubocop:disable Metrics/ClassLength
  attr_accessor(:report)

  def create(report_service:)
    @report = ProfitAndLossReport.find_or_create_by!(
      report_service: report_service,
      template_id: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID,
      slug: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID,
      name: ProfitAndLossReport::PROFITANDLOSS_REPORT_NAME
    )
    sync_report_infos(report: @report)
  end

  def sync_report_infos(report:)
    fetch_all_business_chart_of_accounts(business_id: report.report_service.business_id)
    report_template = ReportTemplate.find_by(template_id: report.template_id)
    sync_pl_report_infos(report: report, report_template: report_template)
  end

  private

  def sync_pl_report_infos(report:, report_template:)
    sync_columns_with_template(report: report, columns: report_template.columns)
    sync_items_with_template(report: report, items: report_template.items)
    sync_accounting_class_check_disabled_with_template(report: report, disabled: report_template.accounting_class_check_disabled)
    sync_enabled_budget_compare(report: report, enabled_budget_compare: report_template.enabled_budget_compare)
    sync_edit_mapping_disabled(report: report, edit_mapping_disabled: report_template.edit_mapping_disabled)
  end

  def sync_accounting_class_check_disabled_with_template(report:, disabled:)
    report.update!(accounting_class_check_disabled: disabled) unless disabled.nil?
  end

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    parent_order = 0
    all_item_identifiers = []
    items.each do |item_json|
      next if item_json.parent_id.present?

      parent_item = report.items.detect { |item| item.identifier == item_json.id }
      parent_item ||= report.items.new(identifier: item_json.id)
      parent_item.name = item_json.name
      parent_item.order = parent_order
      parent_item.totals = false
      parent_item.type_config = item_json.type
      parent_item.values_config = item_json.values
      parent_item.save!

      all_item_identifiers << parent_item.identifier
      parent_order = sync_child_items_with_template(report: report, parent_item: parent_item, items: items, all_item_identifiers: all_item_identifiers)
      parent_order += 1
    end

    report.items.where.not(identifier: { '$in': all_item_identifiers }).destroy_all
  end

  def sync_child_items_with_template(report:, parent_item:, items:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    child_order = parent_item.order

    second_arg_id = second_arg_item_id(item: parent_item)
    biz_chart_of_accounts = @all_business_chart_of_accounts.select { |bcoa| parent_item.name == bcoa.acc_type_name }
    biz_chart_of_accounts.each do |biz_chart_of_account|
      is_child = !biz_chart_of_account.parent_id.nil?
      is_parent_exists = (biz_chart_of_accounts.select { |coa| coa.chart_of_account_id == biz_chart_of_account.parent_id }).length.positive?
      next if is_child && is_parent_exists

      child_order += 1
      child_item = report.items.detect { |item| item.identifier == biz_chart_of_account.chart_of_account_id.to_s }
      child_item ||= report.items.new(identifier: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.name = biz_chart_of_account.name
      child_item.order = child_order
      child_item.totals = false
      child_item.type_config = type_config
      child_item.values_config = values_config(second_arg_id: second_arg_id, item_id: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.parent_id = parent_item.id.to_s
      child_item.save!
      all_item_identifiers << child_item.identifier

      child_cas = @all_business_chart_of_accounts.select { |bcoa| biz_chart_of_account.chart_of_account_id == bcoa.parent_id }
      if child_cas.present?
        child_order = sync_pl_child_items(report: report, parent_item: child_item, child_chart_of_accounts: child_cas,
                                          second_arg_id: second_arg_id, all_item_identifiers: all_item_identifiers)
      end
      sync_item_accounts(item: child_item, chart_of_account: biz_chart_of_account)
    end

    items.each do |child_item_json|
      next if child_item_json.parent_id != parent_item.identifier

      child_order += 1
      child_item = report.items.detect { |item| item.identifier == child_item_json.id }
      child_item ||= report.items.new(identifier: child_item_json.id)
      child_item.name = child_item_json.name
      child_item.order = child_order
      child_item.totals = child_item_json.totals || false
      child_item.show = child_item_json.show.nil? || child_item_json.show
      child_item.negative = child_item_json.negative || false
      child_item.negative_for_total = child_item_json.negative_for_total || false
      child_item.depth_diff = child_item_json.depth_diff || 0
      child_item.type_config = child_item_json.type
      child_item.values_config = child_item_json.values
      child_item.parent_id = parent_item.id.to_s
      child_item.save!
      all_item_identifiers << child_item.identifier
    end
    child_order
  end

  def sync_item_accounts(item:, chart_of_account:)
    item.item_accounts.destroy_all
    item.item_accounts.find_or_create_by!(
      chart_of_account_id: chart_of_account.chart_of_account_id,
      accounting_class_id: nil
    )
  end

  def sync_pl_child_items(report:, parent_item:, child_chart_of_accounts:, second_arg_id:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    child_order = parent_item.order
    child_chart_of_accounts.each do |biz_chart_of_account|
      child_order += 1
      child_cas = @all_business_chart_of_accounts.select { |bcoa| biz_chart_of_account.chart_of_account_id == bcoa.parent_id }
      child_item = report.items.detect { |item| item.identifier == biz_chart_of_account.chart_of_account_id.to_s }
      child_item ||= report.items.new(identifier: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.name = biz_chart_of_account.name
      child_item.order = child_order
      child_item.totals = false
      child_item.type_config = type_config
      child_item.values_config = values_config(second_arg_id: second_arg_id, item_id: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.parent_id = parent_item.id.to_s
      child_item.save!
      all_item_identifiers << child_item.identifier

      sync_item_accounts(item: child_item, chart_of_account: biz_chart_of_account)
      if child_cas.present?
        child_order = sync_pl_child_items(report: report, parent_item: child_item, child_chart_of_accounts: child_cas,
                                          second_arg_id: second_arg_id, all_item_identifiers: all_item_identifiers)
      end
    end
    child_order += 1
    total_item = sync_total_item(report: report, parent_item: parent_item, second_arg_id: second_arg_id, child_order: child_order)
    all_item_identifiers << total_item.identifier
    child_order
  end

  def sync_total_item(report:, parent_item:, second_arg_id:, child_order:)
    child_identifier = "total_#{parent_item.identifier}"
    child_item = report.items.detect { |item| item.identifier == child_identifier }
    child_item ||= report.items.new(identifier: child_identifier)
    child_item.name = "Total #{parent_item.name}"
    child_item.order = child_order
    child_item.totals = true
    child_item.values_config = values_config(second_arg_id: second_arg_id, item_id: child_identifier)
    child_item.parent_id = parent_item.id.to_s
    child_item.save!
    child_item
  end

  def second_arg_item_id(item:)
    stats_formula = item.values_config[Column::TYPE_PERCENTAGE]
    expression = stats_formula['value']['expression']
    expression['arg2']['item_id']
  end

  def type_config
    {
      'name' => 'quickbooks_ledger'
    }
  end

  def values_config(second_arg_id:, item_id:) # rubocop:disable Metrics/MethodLength
    {
      'percentage' => {
        'value' => {
          'expression' => {
            'operator' => '%',
            'arg1' => {
              'item_id' => item_id
            },
            'arg2' => {
              'item_id' => second_arg_id
            }
          }
        }
      }
    }
  end
end
