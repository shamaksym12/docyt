# frozen_string_literal: true

module Api
  module V1
    class ExportReportsController < ApplicationController
      def create
        export_report = case export_report_params[:export_type]
                        when ExportReport::EXPORT_TYPE_REPORT
                          create_for_one_report(export_report_params: export_report_params)
                        when ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT
                          create_for_multi_entity_report(export_report_params: export_report_params)
                        when ExportReport::EXPORT_TYPE_CONSOLIDATED_REPORT
                          create_for_consolidated_report(export_report_params: export_report_params)
                        end
        export_report.request_export_report
        render status: :created, json: { success: true }
      end

      private

      def create_for_one_report(export_report_params:) # rubocop:disable Metrics/MethodLength
        report = Report.find(export_report_params[:report_id])
        filter = {}
        filter = export_report_params[:filter].to_h if export_report_params[:filter]
        filter['accounting_class_id'] = export_report_params[:filter][:accounting_class_id] if report.departmental_report?
        ensure_report_access(report: report, operation: :read)
        ExportReport.create!(
          user_id: secure_user.id,
          export_type: export_report_params[:export_type],
          start_date: export_report_params[:start_date],
          end_date: export_report_params[:end_date],
          filter: filter,
          report_id: report.id
        )
      end

      def create_for_multi_entity_report(export_report_params:) # rubocop:disable Metrics/MethodLength
        multi_business_report = MultiBusinessReport.find(export_report_params[:multi_business_report_id])
        ensure_multi_business_report(multi_business_report: multi_business_report)
        filter = {}
        filter['is_zero_rows_hidden'] = export_report_params[:filter]['is_zero_rows_hidden'] if export_report_params[:filter]
        ExportReport.create!(
          user_id: secure_user.id,
          export_type: export_report_params[:export_type],
          start_date: export_report_params[:start_date],
          end_date: export_report_params[:end_date],
          filter: filter,
          multi_business_report_id: multi_business_report.id
        )
      end

      def create_for_consolidated_report(export_report_params:)
        report_service = ReportService.find_by(service_id: export_report_params[:report_service_id])
        ensure_report_service_access(report_service: report_service, operation: :read)
        ExportReport.create!(
          user_id: secure_user.id,
          export_type: export_report_params[:export_type],
          start_date: export_report_params[:start_date],
          end_date: export_report_params[:end_date],
          filter: {},
          report_service_id: report_service.id
        )
      end

      def export_report_params
        params.permit(:export_type, :start_date, :end_date, :report_id, :multi_business_report_id, :report_service_id, filter: {})
      end
    end
  end
end
