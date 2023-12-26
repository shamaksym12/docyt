# frozen_string_literal: true

module AccountValue
  class MultiBusinessReportItemAccountValuesQuery
    def initialize(multi_business_report:, item_account_values_params:)
      @multi_business_report = multi_business_report
      @item_account_values_params = item_account_values_params
      @reports = @multi_business_report.reports
    end

    def item_account_values
      src_multi_business_item_account_values = @reports.map do |report|
        AccountValue::ItemAccountValuesQuery.new(report: report, item_account_values_params: @item_account_values_params).item_account_values_for_multi_business_report
      end
      generate_aggregated_account_values(src_multi_business_item_account_values: src_multi_business_item_account_values)
    end

    private

    def generate_aggregated_account_values(src_multi_business_item_account_values:) # rubocop:disable Metrics/MethodLength
      return [[], []] if src_multi_business_item_account_values.blank?

      aggregated_item_account_values = {}
      multi_business_item_account_values = []
      src_multi_business_item_account_values.each do |item_account_values_query|
        item_account_values_query.each do |item_account_value|
          next if aggregated_item_account_values[item_account_value.name]

          multi_item_account_values = generate_multi_business_account_values(src_multi_business_item_account_values: src_multi_business_item_account_values,
                                                                             item_account_value: item_account_value)
          sum_amount = multi_item_account_values.sum(&:value)
          multi_business_item_account_values += multi_item_account_values

          aggregated_item_account_values[item_account_value.name] = Struct.new(:id, :chart_of_account_id, :accounting_class_id, :value, :name).new(
            1, item_account_value.chart_of_account_id, item_account_value.accounting_class_id, sum_amount, item_account_value.name
          )
        end
      end

      [aggregated_item_account_values.values, multi_business_item_account_values]
    end

    def generate_multi_business_account_values(src_multi_business_item_account_values:, item_account_value:)
      src_multi_business_item_account_values.map do |values_query|
        business_item_account_value = values_query.detect { |iav| iav.name == item_account_value.name }
        business_item_account_value || Struct.new(:id, :chart_of_account_id, :accounting_class_id, :value, :name).new(
          1, item_account_value.chart_of_account_id, item_account_value.accounting_class_id, 0.0, item_account_value.name
        )
      end
    end
  end
end
