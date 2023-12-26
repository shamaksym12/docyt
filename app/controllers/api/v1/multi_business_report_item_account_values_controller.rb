# frozen_string_literal: true

module Api
  module V1
    class MultiBusinessReportItemAccountValuesController < ApplicationController
      def item_account_values
        ensure_multi_business_report(multi_business_report: multi_business_report)
        account_values = AccountValue::MultiBusinessReportItemAccountValuesQuery.new(multi_business_report: multi_business_report,
                                                                                     item_account_values_params: item_account_values_params).item_account_values
        render status: :ok, json: {
          'aggregated_item_account_values' => account_values[0],
          'business_item_account_values' => account_values[1]
        }, each_serializer: ::ItemAccountValueSerializer
      end

      private

      def multi_business_report
        @multi_business_report ||= MultiBusinessReport.where(_id: params[:multi_business_report_id]).first
      end

      def item_account_values_params
        params.permit(:from, :to, :item_identifier)
      end
    end
  end
end
