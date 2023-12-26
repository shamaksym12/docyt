# frozen_string_literal: true

module ItemValues
  # This class fills the item_value for the column(type=budget_actual)
  class ItemBudgetActualsValueCreator < BaseItemValueCreator # rubocop:disable Metrics/ClassLength
    def call # rubocop:disable Metrics/MethodLength
      if @item.totals
        generate_total_value
      elsif @item.values_config.present? && @item.values_config[Column::TYPE_ACTUAL].present?
        generate_stat_column_value
      elsif @item.use_derived_mapping?
        generate_for_derived_accounts
      elsif standard_metric.present?
        generate_metric_values
      else
        generate_for_mapped_accounts
      end
    end

    private

    def generate_for_derived_accounts # rubocop:disable Metrics/MethodLength
      account_values = []
      budget_values = budgets_by_column.map do |budget|
        budget_items = filtered_budget_actual_items(budget: budget)
        budget_item_values = budget_items.map do |bi|
          budget_item_value = budget_item_item_value(budget_item: bi)
          account_values << { budget_id: budget.id.to_s, chart_of_account_id: bi.chart_of_account_id, accounting_class_id: bi.accounting_class_id, value: budget_item_value }
          budget_item_value
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum }
      end
      generate_item_account_value(account_values: account_values)
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_for_mapped_accounts # rubocop:disable Metrics/MethodLength
      item_accounts = @item.mapped_item_accounts.map { |ia| { chart_of_account_id: ia.chart_of_account_id, accounting_class_id: ia.accounting_class_id } }
      account_values = []
      budget_values = budgets_by_column.map do |budget|
        budget_item_values = item_accounts.map do |ia|
          budget_item = budget_actual_item_by_item_account(budget: budget, item_account: ia)
          budget_item_value = budget_item_item_value(budget_item: budget_item)
          account_values << { budget_id: budget.id.to_s, chart_of_account_id: ia[:chart_of_account_id], accounting_class_id: ia[:accounting_class_id], value: budget_item_value }
          budget_item_value
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum }
      end
      generate_item_account_value(account_values: account_values)
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_metric_values
      item_accounts = @item.mapped_item_accounts.map { |ia| { chart_of_account_id: ia.chart_of_account_id, accounting_class_id: ia.accounting_class_id } }
      item_accounts << { chart_of_account_id: nil, accounting_class_id: nil, standard_metric_id: standard_metric.id.to_s }
      budget_values = budgets_by_column.map do |budget|
        budget_item_values = item_accounts.map do |ia|
          budget_item = budget_actual_item_by_item_account(budget: budget, item_account: ia)
          budget_item_item_value(budget_item: budget_item)
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def generate_total_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      child_items = @item.find_parent_item.all_child_items.reject { |child_item| child_item.id == @item.id }
      budget_values = budgets_by_column.map do |budget|
        budget_item_values = child_items.map do |child_item|
          child_total_item = if child_item.all_child_items.present?
                               child_item.total_item
                             else
                               child_item
                             end
          item_value = actual_value_by_identifier(identifier: child_total_item.identifier, column: @column)
          budget_value = find_budget_value(item_value: item_value, budget: budget)
          value = budget_value.present? ? budget_value[:value] : 0.0
          child_total_item.negative_for_total ? -value : value
        end
        { budget_id: budget.id.to_s, value: budget_item_values.sum + parent_item_value(budget: budget) }
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def parent_item_value(budget:)
      parent_item = @item.find_parent_item
      return 0.0 if parent_item.type_config.blank?

      parent_item_value = actual_value_by_identifier(identifier: parent_item.identifier, column: @column)
      budget_value = find_budget_value(item_value: parent_item_value, budget: budget)
      budget_value.present? ? budget_value[:value] : 0.0
    end

    def generate_stat_column_value # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      budget_values = []
      expression = item_expression(item: @item, target_column_type: Column::TYPE_ACTUAL)
      if expression.present?
        if expression['operator'] == OPERATOR_SUM
          budget_values = budgets_by_column.map do |budget|
            budget_item_value_amounts = sub_item_value_amounts(expression['arg']['sub_items'], budget)
            { budget_id: budget.id.to_s, value: budget_item_value_amounts.sum }
          end
        else
          arg_item_value1 = actual_value_by_identifier(identifier: expression['arg1']['item_id'], column: @column)
          arg_item_value2 = actual_value_by_identifier(identifier: expression['arg2']['item_id'], column: @column)
          budget_values = budgets_by_column.map do |budget|
            arg_budget_value1 = find_budget_value(item_value: arg_item_value1, budget: budget)
            arg_budget_value2 = find_budget_value(item_value: arg_item_value2, budget: budget)
            { budget_id: budget.id.to_s, value: calculate_value_with_operator(arg_budget_value1[:value], arg_budget_value2[:value], expression['operator']) }
          end
        end
      end
      generate_item_value(item: @item, column: @column, budget_values: budget_values)
    end

    def sub_item_value_amounts(sub_items, budget)
      sub_items.map do |sub_item|
        item_value = actual_value_by_identifier(identifier: sub_item['id'], column: @column)
        budget_value = find_budget_value(item_value: item_value, budget: budget)
        value = budget_value.present? ? budget_value[:value] : 0.0
        sub_item['negative'] ? -value : value
      end
    end

    def generate_item_account_value(account_values:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity
      item_accounts = account_values.map { |av| { chart_of_account_id: av[:chart_of_account_id], accounting_class_id: av[:accounting_class_id] } }
      item_accounts = item_accounts.uniq { |ia| [ia[:chart_of_account_id], ia[:accounting_class_id]] }
      item_accounts.each do |ia|
        values = account_values.select { |av| av[:chart_of_account_id] == ia[:chart_of_account_id] && av[:accounting_class_id] == ia[:accounting_class_id] }
        budget_values = values.map { |value| { budget_id: value[:budget_id], value: value[:value] } }
        business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == ia[:chart_of_account_id] }
        accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == ia[:accounting_class_id] }
        create_item_account_value(
          chart_of_account_id: ia[:chart_of_account_id],
          accounting_class_id: ia[:accounting_class_id],
          name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
          budget_values: budget_values
        )
      end
    end

    def standard_metric
      metric_type = (@item.type_config.present? && @item.type_config['metric'].present? && @item.type_config['metric']['name']) || nil
      return nil if metric_type.blank?

      @standard_metrics.detect { |sm| sm.type == metric_type }
    end
  end
end
