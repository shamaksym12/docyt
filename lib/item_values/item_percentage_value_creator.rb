# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=percentage)
  class ItemPercentageValueCreator < BaseItemValueCreator
    def call
      generate_percentage_column_value
    end

    private

    def generate_percentage_column_value
      expression = item_expression(item: @item, target_column_type: @column.type)
      return if expression.blank?

      arg_item_value1 = actual_value_with_arg(arg: expression['arg1'])
      arg_item_value2 = actual_value_with_arg(arg: expression['arg2'])
      item_value_amount = calculate_value_with_operator(arg_item_value1&.value, arg_item_value2&.value, expression['operator'])
      generate_item_value(item: @item, column: @column, item_amount: item_value_amount)
    end
  end
end
