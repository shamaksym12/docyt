# frozen_string_literal: true

module Aggregation
  class BaseItemValueRecalculator < BaseItemValueCalculator
    include DocytLib::Utils::DocytInteractor

    private

    def update_item_value(report_data:, item:, column:, item_amount:, budget_values: [])
      item_value = item_value_from_report_data(report_data: report_data, item: item, column: column)
      if item_value.nil?
        total_item_value = report_data.item_values.new(item_id: item.id.to_s, column_id: column.id.to_s, item_identifier: item.identifier,
                                                       value: item_amount.round(2), budget_values: budget_values)
        total_item_value.generate_column_type_with_infos(item: item, column: column)
      else
        item_value.value = item_amount.round(2)
        item_value.budget_values = budget_values
      end
    end

    def actual_value_by_identifier(report_data:, identifier:, column:)
      item_value = report_data.item_values.detect { |iv| iv.item_identifier == identifier && iv.column_id == column.id.to_s }
      item_value&.value || 0.0
    end

    def item_value_from_report_data(report_data:, item:, column:)
      report_data.item_values.detect { |iv| iv.item_id == item.id.to_s && iv.column_id == column.id.to_s }
    end
  end
end
