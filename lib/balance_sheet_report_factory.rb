# frozen_string_literal: true

class BalanceSheetReportFactory < ReportFactory # rubocop:disable Metrics/ClassLength
  attr_accessor(:report)

  def create(report_service:)
    @report = BalanceSheetReport.find_or_create_by!(
      report_service: report_service,
      template_id: BalanceSheetReport::BALANCE_SHEET_REPORT,
      slug: BalanceSheetReport::BALANCE_SHEET_REPORT,
      name: BalanceSheetReport::BALANCE_SHEET_REPORT_NAME
    )
    sync_report_infos(report: @report)
  end

  def sync_report_infos(report:)
    fetch_all_business_chart_of_accounts(business_id: report.report_service.business_id)
    report_template = ReportTemplate.find_by(template_id: report.template_id)
    sync_balance_sheet_report_infos(report: report, report_template: report_template)
  end

  private

  def sync_balance_sheet_report_infos(report:, report_template:)
    sync_columns_with_template(report: report, columns: report_template.columns)
    sync_items_with_template(report: report, items: report_template.items)
    sync_depends_with_template(report: report, dependent_ids: report_template.depends_on)
    sync_enabled_budget_compare(report: report, enabled_budget_compare: report_template.enabled_budget_compare)
    sync_edit_mapping_disabled(report: report, edit_mapping_disabled: report_template.edit_mapping_disabled)
    sync_visible_total_column(report: report, total_column_visible: report_template.total_column_visible)
    sync_accounting_class_check_disabled_with_template(report: report, disabled: report_template.accounting_class_check_disabled)
    report.save!
  end

  def sync_accounting_class_check_disabled_with_template(report:, disabled:)
    report.update!(accounting_class_check_disabled: disabled) unless disabled.nil?
  end

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    current_order = 0
    all_item_identifiers = []
    items.each do |item_json|
      next if item_json.parent_id.present?

      parent_item = report.items.detect { |item| item.identifier == item_json.id }
      parent_item ||= report.items.new(identifier: item_json.id)
      parent_item.name = item_json.name
      parent_item.order = current_order
      parent_item.totals = false
      parent_item.type_config = item_json.type
      parent_item.values_config = item_json.values
      parent_item.save!

      all_item_identifiers << parent_item.identifier
      current_order = sync_child_items_with_template(report: report, parent_item: parent_item, items: items, all_item_identifiers: all_item_identifiers)
      current_order += 1
    end

    report.items.where.not(identifier: { '$in': all_item_identifiers }).destroy_all
  end

  def sync_child_items_with_template(report:, parent_item:, items:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    current_order = parent_item.order
    items.each do |child_item_json|
      next if child_item_json.parent_id != parent_item.identifier

      current_order += 1
      child_item = report.items.detect { |item| item.identifier == child_item_json.id }
      child_item ||= report.items.new(identifier: child_item_json.id)
      child_item.name = child_item_json.name
      child_item.order = current_order
      child_item.totals = child_item_json.totals || false
      child_item.show = child_item_json.show.nil? || child_item_json.show
      child_item.negative = child_item_json.negative || false
      child_item.negative_for_total = child_item_json.negative_for_total || false
      child_item.depth_diff = child_item_json.depth_diff || 0
      child_item.type_config = child_item_json.type
      child_item.values_config = child_item_json.values
      child_item.account_type = child_item_json.account_type
      child_item.parent_id = parent_item.id.to_s
      child_item.save!
      all_item_identifiers << child_item.identifier

      current_order =
        if child_item_json.account_type.present?
          generate_balance_sheet_parent_items(report: report, parent_item: child_item, items: items, all_item_identifiers: all_item_identifiers)
        else
          sync_child_items_with_template(report: report, parent_item: child_item, items: items, all_item_identifiers: all_item_identifiers)
        end
    end
    current_order
  end

  def generate_balance_sheet_parent_items(report:, parent_item:, items:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    current_order = parent_item.order
    second_arg_id = second_arg_item_id(item: parent_item)
    biz_chart_of_accounts = @all_business_chart_of_accounts.select { |bcoa| parent_item.account_type == bcoa.acc_type }
    biz_chart_of_accounts.each do |biz_chart_of_account|
      is_child = !biz_chart_of_account.parent_id.nil?
      is_parent_exists = (biz_chart_of_accounts.select { |coa| coa.chart_of_account_id == biz_chart_of_account.parent_id }).length.positive?
      next if is_child && is_parent_exists

      current_order += 1
      item = report.items.detect { |itm| itm.identifier == biz_chart_of_account.chart_of_account_id.to_s }
      item ||= report.items.new(identifier: biz_chart_of_account.chart_of_account_id.to_s)
      item.name = biz_chart_of_account.name
      item.order = current_order
      item.totals = false
      item.type_config = type_config
      item.values_config = values_config(second_arg_id: second_arg_id, item_id: biz_chart_of_account.chart_of_account_id.to_s)
      item.parent_id = parent_item.id.to_s
      item.save!

      all_item_identifiers << item.identifier

      sync_item_accounts(item: item, chart_of_account: biz_chart_of_account)

      child_cas = @all_business_chart_of_accounts.select { |bcoa| biz_chart_of_account.chart_of_account_id == bcoa.parent_id }
      if child_cas.present?
        current_order = generate_balance_sheet_child_items(report: report, parent_item: item, child_chart_of_accounts: child_cas,
                                                           second_arg_id: second_arg_id, all_item_identifiers: all_item_identifiers)
      end
    end

    items.each do |item_json|
      next if item_json.parent_id != parent_item.identifier

      current_order += 1
      fixed_item = report.items.detect { |item| item.identifier == item_json.id }
      fixed_item ||= report.items.new(identifier: item_json.id)
      fixed_item.name = item_json.name
      fixed_item.order = current_order
      fixed_item.totals = item_json.totals || false
      fixed_item.show = item_json.show.nil? || item_json.show
      fixed_item.negative = item_json.negative || false
      fixed_item.negative_for_total = item_json.negative_for_total || false
      fixed_item.depth_diff = item_json.depth_diff || 0
      fixed_item.type_config = item_json.type
      fixed_item.values_config = item_json.values
      fixed_item.parent_id = parent_item.id.to_s
      fixed_item.save!
      all_item_identifiers << fixed_item.identifier
    end
    current_order
  end

  def generate_balance_sheet_child_items(report:, parent_item:, child_chart_of_accounts:, second_arg_id:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    current_order = parent_item.order
    child_chart_of_accounts.each do |biz_chart_of_account|
      child_cas = @all_business_chart_of_accounts.select { |bcoa| biz_chart_of_account.chart_of_account_id == bcoa.parent_id }

      current_order += 1
      child_item = report.items.find_or_initialize_by(identifier: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.name = biz_chart_of_account.name
      child_item.order = current_order
      child_item.totals = false
      child_item.type_config = type_config
      child_item.values_config = values_config(second_arg_id: second_arg_id, item_id: biz_chart_of_account.chart_of_account_id.to_s)
      child_item.parent_id = parent_item.id.to_s
      child_item.save!

      all_item_identifiers << child_item.identifier
      sync_item_accounts(item: child_item, chart_of_account: biz_chart_of_account)
      if child_cas.present?
        current_order = generate_balance_sheet_child_items(report: report, parent_item: child_item, child_chart_of_accounts: child_cas,
                                                           second_arg_id: second_arg_id, all_item_identifiers: all_item_identifiers)
      end
    end
    current_order += 1
    total_item = sync_total_item(report: report, parent_item: parent_item, second_arg_id: second_arg_id, child_order: current_order)
    all_item_identifiers << total_item.identifier
    current_order
  end

  def sync_item_accounts(item:, chart_of_account:)
    item.item_accounts.destroy_all
    item.item_accounts.find_or_create_by!(chart_of_account_id: chart_of_account.chart_of_account_id)
  end

  def sync_total_item(report:, parent_item:, second_arg_id:, child_order:)
    child_identifier = "total_#{parent_item.identifier}"
    total_item = report.items.find_or_initialize_by(identifier: child_identifier)
    total_item.name = "Total #{parent_item.name}"
    total_item.order = child_order
    total_item.totals = true
    total_item.values_config = values_config(second_arg_id: second_arg_id, item_id: child_identifier)
    total_item.parent_id = parent_item.id.to_s
    total_item.save!
    total_item
  end

  def second_arg_item_id(item:)
    stats_formula = item.values_config[Column::TYPE_PERCENTAGE]
    expression = stats_formula['value']['expression']
    expression['arg2']['item_id']
  end

  def type_config
    {
      'name' => 'quickbooks_ledger',
      'calculation_type' => 'balance_sheet'
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
