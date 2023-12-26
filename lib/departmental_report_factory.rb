# frozen_string_literal: true

class DepartmentalReportFactory < ReportFactory
  ITEM_REVENUE = 'revenue'
  ITEM_EXPENSE = 'expenses'
  ITEM_PROFIT = 'profit'

  def sync_report_infos(report:)
    fetch_accounting_classes(business_id: report.report_service.business_id)
    super(report: report)
  end

  private

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength
    current_order = 0
    all_item_identifiers = []
    items.each do |item_json|
      parent_item = report.items.detect { |item| item.identifier == item_json.id }
      parent_item ||= report.items.new(identifier: item_json.id)
      parent_item.update!(name: item_json.name, order: current_order, totals: false)
      all_item_identifiers << item_json.id
      sync_child_items(report: report, parent_item: parent_item, parent_class_external_id: nil, identifier_prefix: item_json.id,
                       first_step: true, root_identifier: item_json.id, all_item_identifiers: all_item_identifiers)
      current_order += 1
    end

    report.items.where.not(identifier: { '$in': all_item_identifiers }).destroy_all
  end

  def sync_child_items(report:, parent_item:, parent_class_external_id:, identifier_prefix:, first_step:, root_identifier:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists
    child_accounting_classes = @accounting_classes.select { |accounting_class| accounting_class.parent_external_id == parent_class_external_id }

    child_order = parent_item.order
    child_accounting_classes.each do |child_accounting_class|
      child_order += 1
      child_identifier = "#{identifier_prefix}_#{child_accounting_class.external_id}"
      all_item_identifiers << child_identifier
      sub_child_classes = @accounting_classes.select { |accounting_class| accounting_class.parent_external_id == child_accounting_class.external_id }

      type_config = sub_child_classes.blank? ? type_config_for_child_item(root_identifier: root_identifier, accounting_class: child_accounting_class) : nil
      value_config = sub_child_classes.blank? ? value_config_for_child_item(root_identifier: root_identifier, child_identifier: child_identifier) : nil
      child_item = report.items.detect { |item| item.identifier == child_identifier }
      child_item ||= report.items.new(identifier: child_identifier)
      child_item.update!(name: child_accounting_class.name, order: child_order, totals: false,
                         type_config: type_config, values_config: value_config, parent_id: parent_item.id.to_s)
      child_item.item_accounts.destroy_all
      child_item.item_accounts.create!(accounting_class_id: child_accounting_class.id)
      child_order = sync_child_items(report: report, parent_item: child_item, parent_class_external_id: child_accounting_class.external_id,
                                     identifier_prefix: child_item.identifier, first_step: false, root_identifier: root_identifier, all_item_identifiers: all_item_identifiers)
    end
    if child_accounting_classes.present?
      child_order += 1
      sync_total_item(report: report, parent_item: parent_item, child_order: child_order, first_step: first_step,
                      parent_class_external_id: parent_class_external_id, all_item_identifiers: all_item_identifiers)
    end
    child_order
  end

  def sync_total_item(report:, parent_item:, child_order:, first_step:, parent_class_external_id:, all_item_identifiers:) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    child_identifier = "total_#{parent_item.identifier}"
    child_item = report.items.detect { |item| item.identifier == child_identifier }
    if child_item.present?
      child_item.item_accounts.destroy_all
    elsif child_item.blank?
      child_item = report.items.create!(name: "Total #{parent_item.name}", order: child_order, identifier: child_identifier,
                                        show: first_step, negative: false, totals: true, parent_id: parent_item.id.to_s)
    end
    all_item_identifiers << child_identifier
    parent_accounting_class = @accounting_classes.detect { |accounting_class| accounting_class.external_id == parent_class_external_id }
    child_item.item_accounts.create!(accounting_class_id: parent_accounting_class.id) if parent_accounting_class.present?
  end

  def type_config_for_child_item(root_identifier:, accounting_class:) # rubocop:disable Metrics/MethodLength
    case root_identifier
    when ITEM_REVENUE
      {
        'name' => 'quickbooks_ledger',
        'general_ledger_options' => {
          'only_classes' => [accounting_class.external_id],
          'include_account_types' => [
            'Income',
            'Other Income'
          ]
        }
      }
    when ITEM_EXPENSE
      {
        'name' => 'quickbooks_ledger',
        'general_ledger_options' => {
          'only_classes' => [accounting_class.external_id],
          'include_account_types' => [
            'Expense',
            'Cost Of Goods Sold',
            'Other Expense'
          ]
        }
      }
    when ITEM_PROFIT
      { name: 'stats' }
    end
  end

  def value_config_for_child_item(root_identifier:, child_identifier:) # rubocop:disable Metrics/MethodLength
    return nil if root_identifier != ITEM_PROFIT

    prefix_length = ITEM_PROFIT.length
    revenue_item_identifier = "#{ITEM_REVENUE}#{child_identifier.slice(prefix_length..-1)}"
    expense_item_identifier = "#{ITEM_EXPENSE}#{child_identifier.slice(prefix_length..-1)}"

    {
      'actual' => {
        'value' => {
          'expression' => {
            'operator' => '-',
            'arg1' => {
              'item_id' => revenue_item_identifier
            },
            'arg2' => {
              'item_id' => expense_item_identifier
            }
          }
        }
      }
    }
  end
end
