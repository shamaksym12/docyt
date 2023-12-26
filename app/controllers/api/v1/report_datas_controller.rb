# frozen_string_literal: true

module Api
  module V1
    class ReportDatasController < ApplicationController
      def by_range
        ensure_report_access(report: report, operation: :read)
        report_data_query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: report.total_column_visible)
        render status: :ok, json: report_data_query.report_datas, each_serializer: ::ReportDataSerializer
      end

      def update_data
        ensure_report_access(report: report, operation: :read)
        ReportFactory.enqueue_report_datas_update(report: report, params: update_report_datas_params)
        render status: :ok, json: { success: true }
      end

      def report_datas_params
        params.permit(:from, :to, :current, :is_daily)
      end

      def update_report_datas_params
        params.permit(:start_date, :end_date, :period_type)
      end
    end
  end
end
