# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_variance)
  class ItemBudgetVarianceValueCreator < BaseItemValueCreator
    def call
      generate_variance_column_value
    end

    private

    def generate_variance_column_value # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      actual_column = @report.columns.detect { |cl| cl.type == Column::TYPE_ACTUAL && cl.range == @column.range && cl.year == Column::YEAR_CURRENT }
      budget_actual_column = @report.columns.detect { |cl| cl.type == Column::TYPE_BUDGET_ACTUAL && cl.range == @column.range && cl.year == Column::YEAR_CURRENT }
      actual_item_value = @report_data.item_values.detect { |iv| iv.item_id == @item.id.to_s && iv.column_id == actual_column.id.to_s }
      budget_actual_item_value = @report_data.item_values.detect { |iv| iv.item_id == @item.id.to_s && iv.column_id == budget_actual_column.id.to_s }
      budget_values = budget_actual_item_value.budget_values.map do |budget_value|
        { budget_id: budget_value[:budget_id], value: actual_item_value.value - budget_value[:value] }
      end
      generate_item_account_value(actual_column: actual_column, budget_actual_column: budget_actual_column)
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_item_account_value(actual_column:, budget_actual_column:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      actual_item_account_values = @report_data.item_account_values.select { |iav| iav.item_id == @item.id.to_s && iav.column_id == actual_column.id.to_s }
      budget_actual_item_account_values = @report_data.item_account_values.select { |iav| iav.item_id == @item.id.to_s && iav.column_id == budget_actual_column.id.to_s }

      if @item.use_derived_mapping?
        actual_item_account_values.each do |aiav|
          budget_actual_item_account_value = budget_actual_item_account_values.detect do |baiav|
            baiav.chart_of_account_id == aiav.chart_of_account_id && baiav.accounting_class_id == aiav.accounting_class_id
          end
          next if budget_actual_item_account_value.nil?

          budget_values = budget_actual_item_account_value.budget_values.map do |budget_value|
            { budget_id: budget_value[:budget_id], value: calculate_value_with_operator(aiav.value, budget_value[:value], '-') }
          end
          create_item_account_value(
            chart_of_account_id: aiav.chart_of_account_id,
            accounting_class_id: aiav.accounting_class_id,
            budget_values: budget_values
          )
        end
      else
        @item.mapped_item_accounts.each do |item_account|
          actual_item_account_value = actual_item_account_values.detect do |aiav|
            aiav.chart_of_account_id == item_account.chart_of_account_id && aiav.accounting_class_id == item_account.accounting_class_id
          end
          budget_actual_item_account_value = budget_actual_item_account_values.detect do |baiav|
            baiav.chart_of_account_id == item_account.chart_of_account_id && baiav.accounting_class_id == item_account.accounting_class_id
          end
          next if actual_item_account_value.nil? || budget_actual_item_account_value.nil?

          budget_values = budget_actual_item_account_value.budget_values.map do |budget_value|
            { budget_id: budget_value[:budget_id], value: calculate_value_with_operator(actual_item_account_value&.value, budget_value[:value], '-') }
          end
          create_item_account_value(
            chart_of_account_id: item_account.chart_of_account_id,
            accounting_class_id: item_account.accounting_class_id,
            budget_values: budget_values
          )
        end
      end
    end
  end
end
