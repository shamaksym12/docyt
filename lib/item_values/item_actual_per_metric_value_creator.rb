# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=par_actual,por_actual)
  class ItemActualPerMetricValueCreator < BaseItemValueCreator
    def call
      return if @item.type_config.present? && @item.type_config['name'] == Item::TYPE_METRIC && @item.per_metric_calculation_enabled == false
      return if @item.values_config.present? && @item.values_config.dig('actual', 'value', 'expression', 'operator') == '%'

      generate_column_value
    end

    private

    def generate_column_value # rubocop:disable Metrics/MethodLength
      metric_value = find_metric_value
      item_value_amount = calculate_value_with_operator(actual_item_value&.value, metric_value, '/')
      item_value = generate_item_value(item: @item, column: @column, item_amount: item_value_amount.round(2))
      actual_item_account_values.each do |aiav|
        item_account_value_amount = calculate_value_with_operator(aiav.value, metric_value, '/')
        create_item_account_value(
          chart_of_account_id: aiav.chart_of_account_id,
          accounting_class_id: aiav.accounting_class_id,
          name: aiav.name, value: item_account_value_amount.round(2)
        )
      end
      item_value
    end

    def source_column
      @report_data.report.columns.detect { |column| column.type == Column::TYPE_ACTUAL && column.range == @column.range && column.year == @column.year }
    end

    def find_metric_value
      actual_value_by_identifier(identifier: @column.per_metric, column: source_column)&.value || 0.0
    end

    def actual_item_value
      actual_value_by_identifier(identifier: @item.identifier, column: source_column)
    end

    def actual_item_account_values
      @report_data.item_account_values.select { |iav| iav.item_id == @item.id.to_s && iav.column_id == source_column.id.to_s }
    end
  end
end
