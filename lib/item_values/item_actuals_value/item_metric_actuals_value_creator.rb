# frozen_string_literal: true

# This creator can calculate both of Monthly and YTD value
module ItemValues
  module ItemActualsValue
    class ItemMetricActualsValueCreator < ItemValues::BaseItemValueCreator
      def call
        generate_from_metric
      end

      private

      def generate_from_metric
        start_date = start_date_by_column(@report_data)
        start_date = start_date.at_beginning_of_year if @column.range == Column::RANGE_YTD
        response = MetricsServiceClient::ValueApi.new.get_metric_value(
          @report.report_service.business_id,
          metric_code,
          start_date,
          end_date_by_column(@report_data)
        )
        item_amount = @report.enabled_blank_value_for_metric ? response.value : response.value.to_f
        generate_item_value(item: @item, column: @column, item_amount: item_amount)
      end

      def metric_code
        @item.type_config['metric']['code']
      end
    end
  end
end
