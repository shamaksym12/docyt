# frozen_string_literal: true

module Aggregation
  class ItemActualsValueRecalculator < BaseItemValueRecalculator
    def call(report_datas:, report_data:, dependent_report_datas:, column:, item:) # rubocop:disable Metrics/MethodLength
      if (column.type == Column::TYPE_BUDGET_ACTUAL && item.values_config.present? && item.values_config[Column::TYPE_ACTUAL].present?) ||
         (item.values_config.present? && item.values_config[column.type].present?)
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
        update_actual_value(report_datas: report_datas, report_data: report_data, column: column, item: item)
      end
    end

    private

    def update_actual_value(report_datas:, report_data:, column:, item:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      total_item_value_amount = 0.0
      budget_values = []
      if column.type == Column::TYPE_BUDGET_ACTUAL
        budget_values = report_data.budget_ids.map do |bi|
          value = 0.0
          report_datas.each do |rd|
            item_value = item_value_from_report_data(report_data: rd, item: item, column: column)
            next if item_value.nil?

            budget_value = item_value.budget_values.detect { |bv| bv[:budget_id] == bi } || {}
            value += budget_value[:value] || 0.0
          end
          { budget_id: bi, value: value }
        end
      elsif item.type_config.present? && (item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE ||
        (item.type_config['name'] == Item::TYPE_REFERENCE && item.type_config['src_column_range'] == Column::RANGE_YTD))
        previous_report_data = item.prior_balance_day_option? ? report_datas.first : report_datas.last
        total_item_value_amount = actual_value_by_identifier(report_data: previous_report_data, identifier: item.identifier, column: column)
      else
        report_datas.each { |rd| total_item_value_amount += actual_value_by_identifier(report_data: rd, identifier: item.identifier, column: column) }
        if item.type_config['multi_month_calculation_type'] == Item::MULTI_MONTH_CALCULATION_AVERAGE_TYPE
          count = (report_data.end_date.year * 12) + report_data.end_date.month - (report_data.start_date.year * 12) - report_data.start_date.month + 1
          total_item_value_amount /= count
        end
      end
      update_item_value(report_data: report_data, item: item, column: column, item_amount: total_item_value_amount, budget_values: budget_values)
    end

    def generate_stat_column_value(report_data:, dependent_report_datas:, item:, column:) # rubocop:disable Metrics/MethodLength
      creator_class = if column.type == Column::TYPE_BUDGET_ACTUAL
                        ItemValues::ItemBudgetActualsValueCreator
                      else
                        ItemValues::ItemActualsValue::ItemStatActualsValueCreator
                      end

      creator_instance = creator_class.new(
        report_data: report_data,
        item: item,
        column: column,
        standard_metrics: nil,
        dependent_report_datas: dependent_report_datas,
        all_business_chart_of_accounts: nil,
        accounting_classes: nil,
        caching_report_datas_service: ItemValues::CachingReportDatasService.new(report_data.report.report_service),
        caching_general_ledgers_service: nil
      )
      creator_instance.call
    end

    def generate_total_value(report_data:, dependent_report_datas:, item:, column:) # rubocop:disable Metrics/MethodLength
      creator_class = if column.type == Column::TYPE_BUDGET_ACTUAL
                        ItemValues::ItemBudgetActualsValueCreator
                      else
                        ItemValues::ItemActualsValue::ItemTotalActualsValueCreator
                      end

      creator_instance = creator_class.new(
        report_data: report_data,
        item: item,
        column: column,
        standard_metrics: nil,
        dependent_report_datas: dependent_report_datas,
        all_business_chart_of_accounts: nil,
        accounting_classes: nil,
        caching_report_datas_service: ItemValues::CachingReportDatasService.new(report_data.report.report_service),
        caching_general_ledgers_service: nil
      )
      creator_instance.call
    end
  end
end
