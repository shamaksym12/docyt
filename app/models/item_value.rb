# frozen_string_literal: true

class ItemValue
  include Mongoid::Document

  field :value, type: Float # This value can be nil, it means no data for metric item.
  field :column_type, type: String
  field :item_id, type: String
  field :column_id, type: String
  field :item_identifier, type: String
  field :budget_values, type: Array, default: [] # [{budget_id: id, value: 0.0}]

  embedded_in :report_data, class_name: 'ReportData'

  def generate_column_type
    report = report_data.report
    item = report.find_item_by_id(id: item_id)
    column = report.columns.detect { |c| c.id.to_s == column_id }
    generate_column_type_with_infos(item: item, column: column)
  end

  def generate_column_type_with_infos(item:, column:)
    stats_formula = item.values_config.present? ? item.values_config[Column::TYPE_ACTUAL] : nil

    self.column_type = if percentage_column?(column.type) || stats_formula_percentage?(stats_formula)
                         Column::TYPE_PERCENTAGE
                       elsif variance_column?(item.type_config, item.metric_data_type)
                         Column::TYPE_VARIANCE
                       else
                         Column::TYPE_ACTUAL
                       end
  end

  private

  def percentage_column?(column_type)
    [
      Column::TYPE_PERCENTAGE,
      Column::TYPE_BUDGET_PERCENTAGE,
      Column::TYPE_GROSS_PERCENTAGE,
      Column::TYPE_VARIANCE_PERCENTAGE
    ].include?(column_type)
  end

  def stats_formula_percentage?(stats_formula)
    stats_formula&.dig('value', 'expression', 'operator') == '%'
  end

  def variance_column?(type_config, data_type = nil)
    return false if data_type == Item::METRIC_CURRENCY_DATA_TYPE
    return true if data_type == Item::METRIC_INTEGER_DATA_TYPE

    type_config&.dig('name') == Item::TYPE_METRIC || type_config&.dig('name') == Item::TYPE_REFERENCE
  end
end
