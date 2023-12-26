# frozen_string_literal: true

module ItemValues
  class ItemValueCreator
    def initialize( # rubocop:disable Metrics/ParameterLists
      report_data:,
      standard_metrics:,
      dependent_report_datas:,
      all_business_chart_of_accounts:,
      accounting_classes:,
      caching_report_datas_service:,
      caching_general_ledgers_service:
    )
      @report_data = report_data
      @report = report_data.report
      @standard_metrics = standard_metrics
      @dependent_report_datas = dependent_report_datas
      @all_business_chart_of_accounts = all_business_chart_of_accounts
      @accounting_classes = accounting_classes
      @caching_report_datas_service = caching_report_datas_service
      @caching_general_ledgers_service = caching_general_ledgers_service
    end

    def call(column:, item:) # rubocop:disable Metrics/MethodLength
      return nil unless can_create_item_value?(item: item)

      item_value_creator_class = creator_class(column: column)
      creator_instance = item_value_creator_class.new(
        report_data: @report_data, item: item, column: column,
        standard_metrics: @standard_metrics,
        dependent_report_datas: @dependent_report_datas,
        all_business_chart_of_accounts: @all_business_chart_of_accounts,
        accounting_classes: @accounting_classes,
        caching_report_datas_service: @caching_report_datas_service,
        caching_general_ledgers_service: @caching_general_ledgers_service
      )
      creator_instance.call
    end

    private

    def creator_class(column:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      case column.type
      when Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL
        ItemActualsValue::ItemActualsValueCreator
      when Column::TYPE_ACTUAL_PER_METRIC
        ItemActualPerMetricValueCreator
      when Column::TYPE_PERCENTAGE, Column::TYPE_GROSS_PERCENTAGE, Column::TYPE_VARIANCE_PERCENTAGE
        ItemPercentageValueCreator
      when Column::TYPE_VARIANCE
        ItemVarianceValueCreator
      when Column::TYPE_BUDGET_ACTUAL
        ItemBudgetActualsValueCreator
      when Column::TYPE_BUDGET_PERCENTAGE
        ItemBudgetPercentageValueCreator
      when Column::TYPE_BUDGET_VARIANCE
        ItemBudgetVarianceValueCreator
      end
    end

    def can_create_item_value?(item:)
      return false if item.type_config.blank? && !item.totals

      true
    end
  end
end
