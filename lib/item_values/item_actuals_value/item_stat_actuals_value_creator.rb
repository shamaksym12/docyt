# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemStatActualsValueCreator < ItemValues::BaseItemValueCreator
      def call
        generate_stat_column_value
      end

      private

      def generate_stat_column_value # rubocop:disable Metrics/MethodLength
        expression = item_expression(item: @item, target_column_type: @column.type)
        item_value_amount = 0.0
        if expression.present?
          if expression['operator'] == OPERATOR_SUM
            child_item_values = sub_item_value_amounts(expression['arg']['sub_items'])
            item_value_amount = child_item_values.sum
          else
            arg_item_value1 = actual_value_with_arg(arg: expression['arg1'])
            arg_item_value2 = actual_value_with_arg(arg: expression['arg2'])
            item_value_amount = calculate_value_with_operator(arg_item_value1&.value, arg_item_value2&.value, expression['operator'])
          end
        end
        generate_item_value(item: @item, column: @column, item_amount: item_value_amount)
      end

      def sub_item_value_amounts(sub_items)
        sub_items.map do |sub_item|
          item_value = actual_value_by_identifier(identifier: sub_item['id'], column: @column)
          value = item_value&.value || 0.0
          sub_item['negative'] ? -value : value
        end
      end
    end
  end
end
