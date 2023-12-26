# frozen_string_literal: true

module Api
  module V1
    class MultiBusinessReportDatasController < ApplicationController
      def by_range
        ensure_multi_business_report(multi_business_report: multi_business_report)
        report_data_query = MultiBusinessReportDatasQuery.new(multi_business_report: multi_business_report, report_datas_params: report_datas_params)
        report_datas = report_data_query.report_datas
        render status: :ok, json: report_datas, each_serializer: ::ReportDataSerializer, root: 'report_datas'
      end

      def update_daily_report_datas
        ensure_multi_business_report(multi_business_report: multi_business_report)
        multi_business_report.update_daily_report_datas(current_date: report_datas_params[:current])
        report_data_query = MultiBusinessReportDatasQuery.new(multi_business_report: multi_business_report, report_datas_params: report_datas_params)
        report_datas = report_data_query.report_datas
        render status: :ok, json: report_datas, each_serializer: ::ReportDataSerializer, root: 'report_datas'
      end

      private

      def multi_business_report
        @multi_business_report ||= MultiBusinessReport.where(_id: params[:multi_business_report_id]).first
      end

      def report_datas_params
        params.permit(:from, :to, :current, :is_daily)
      end
    end
  end
end
