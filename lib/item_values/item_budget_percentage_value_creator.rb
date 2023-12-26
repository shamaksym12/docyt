# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_percentage)
  class ItemBudgetPercentageValueCreator < BaseItemValueCreator
    def call
      generate_percentage_column_value
    end

    private

    def generate_percentage_column_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      expression = item_expression(item: @item, target_column_type: Column::TYPE_PERCENTAGE)
      return if expression.blank?

      source_column = @report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: @column.range, year: @column.year)
      arg_item_value1 = actual_value_by_identifier(identifier: expression['arg1']['item_id'], column: source_column)
      arg_item_value2 = actual_value_by_identifier(identifier: expression['arg2']['item_id'], column: source_column)
      account_values = []
      budget_values = budgets_by_column.map do |budget|
        arg_budget_value1 = find_budget_value(item_value: arg_item_value1, budget: budget)
        arg_budget_value2 = find_budget_value(item_value: arg_item_value2, budget: budget)
        account_values += budget_percentage_value(budget: budget, arg_item_value2: arg_item_value2)
        { budget_id: budget.id.to_s, value: calculate_value_with_operator(arg_budget_value1[:value], arg_budget_value2[:value], expression['operator']) }
      end
      generate_item_account_value(account_values: account_values)
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def budget_percentage_value(budget:, arg_item_value2:)
      @item.mapped_item_accounts.map do |item_account|
        budget_item = budget_actual_item_by_item_account(budget: budget, item_account: item_account)
        budget_item_account_value = budget_item_item_value(budget_item: budget_item)
        arg_budget_value2 = find_budget_value(item_value: arg_item_value2, budget: budget)
        value = calculate_value_with_operator(budget_item_account_value, arg_budget_value2[:value], '%')
        { budget_id: budget.id.to_s, chart_of_account_id: item_account.chart_of_account_id, accounting_class_id: item_account.accounting_class_id, value: value }
      end
    end

    def generate_item_account_value(account_values:)
      @item.mapped_item_accounts.each do |item_account|
        values = account_values.select { |bav| bav[:chart_of_account_id] == item_account.chart_of_account_id && bav[:accounting_class_id] == item_account.accounting_class_id }
        budget_values = values.map { |value| { budget_id: value[:budget_id], value: value[:value] } }
        create_item_account_value(
          chart_of_account_id: item_account.chart_of_account_id,
          accounting_class_id: item_account.accounting_class_id,
          budget_values: budget_values
        )
      end
    end
  end
end
