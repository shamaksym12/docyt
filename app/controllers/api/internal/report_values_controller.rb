# frozen_string_literal: true

module Api
  module Internal
    class ReportValuesController < InternalBaseController
      def index
        report_service = ReportService.find_by(business_id: params[:business_id])
        report_values_query = ReportValuesQuery.new(report_service: report_service, report_values_params: report_values_params)
        report_values = report_values_query.report_values
        if report_values.blank?
          render status: :ok, json: []
        else
          render status: :ok, json: report_values, each_serializer: Api::Internal::ReportValueSerializer
        end
      end

      private

      def report_values_params
        params.permit(:business_id, :template_id, :slug, :from, :to, :item_identifier, :period_type, :column_year,
                      :column_type, :column_per_metric)
      end
    end
  end
end
