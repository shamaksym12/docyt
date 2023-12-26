# frozen_string_literal: true

module Aggregation
  class MultiBusinessItemActualsValueRecalculator < ItemActualsValueRecalculator
    def call(report_datas:, report_data:, dependent_report_datas:, actual_columns:, column:, item:) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
      @actual_columns = actual_columns
      if item.values_config.present? && item.values_config[column.type].present?
        generate_stat_column_value(
          report_data: report_data,
          dependent_report_datas: dependent_report_datas,
          item: item,
          column: column
        )
      elsif item.totals
        generate_total_value(
          report_data: report_data,
          dependent_report_datas: dependent_report_datas,
          item: item,
          column: column
        )
      else
        update_actual_value(report_datas: report_datas, report_data: report_data, aggregated_column: column, item: item)
      end
    end

    private

    def update_actual_value(report_datas:, report_data:, aggregated_column:, item:)
      aggregated_item_amount = 0.0
      report_datas.each do |multi_business_report_data|
        column = get_actual_column(report_data_id: multi_business_report_data.id.to_s)
        item_value = multi_business_report_data.item_values.detect { |iv| iv.item_identifier == item.identifier && iv.column_id == column.id.to_s }
        aggregated_item_amount += item_value&.value || 0.0
      end
      aggregated_item_value = report_data.item_values.new(item_id: item.id.to_s, column_id: aggregated_column.id.to_s,
                                                          value: aggregated_item_amount.round(2), item_identifier: item.identifier)
      aggregated_item_value.generate_column_type_with_infos(item: item, column: aggregated_column)
    end

    def get_actual_column(report_data_id:)
      @actual_columns[report_data_id]
    end
  end
end
