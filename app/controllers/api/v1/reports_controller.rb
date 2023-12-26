# frozen_string_literal: true

module Api
  module V1
    class ReportsController < ApplicationController
      def index
        raise NoPermissionException unless user_access_manager.can_access_to_report_service(report_service: report_service, operation: :read)

        reports = report_service.reports.all
        render status: :ok, json: reports, each_serializer: ::ReportSerializer
      end

      def show
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report, serializer: ::ReportSerializer
      end

      # Deprecated
      def by_template_id
        report_service = ReportService.find_by(business_id: params[:business_id])
        report = report_service.reports.find_by(slug: params[:template_id])
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report, serializer: ::ReportSerializer
      end

      def by_slug
        report_service = ReportService.find_by(business_id: params[:business_id])
        report = report_service.reports.find_by(slug: params[:slug])
        # The viewer cannot access basic reports.
        if [ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID, BalanceSheetReport::BALANCE_SHEET_REPORT].include?(params[:slug])
          ensure_report_service_access(report_service: report_service, operation: :write)
        else
          ensure_report_access(report: report, operation: :read)
        end

        render status: :ok, json: report, serializer: ::ReportSerializer
      end

      def update
        report = Report.find(params[:id])
        ensure_report_service_access(report_service: report.report_service, operation: :write)
        report_result = ReportFactory.update(report: report, report_params: report_params)
        if report_result.success?
          render status: :ok, json: report.reload, serializer: ::ReportSerializer
        else
          render status: 422, json: { errors: report_result.errors }
        end
      end

      def destroy
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :write)
        report.destroy!
        render status: :ok, json: { success: true }
      end

      def update_report
        report = Report.find(params[:id])
        ensure_report_access(report: report, operation: :read)
        ReportFactory.enqueue_report_update(report: report)
        render status: :ok, json: report.reload, serializer: ::ReportSerializer
      end

      def available_businesses
        render status: :ok, json: BusinessesQuery.new.available_businesses(user: secure_user, template_id: params[:template_id]), root: 'available_businesses'
      end

      def last_updated_date
        report_service = ReportService.find_by(business_id: params[:business_id])
        report = report_service.reports.find_by(slug: params[:slug])
        ensure_report_access(report: report, operation: :read)
        report_data_query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: false)
        render status: :ok, json: { last_updated_date: report_data_query.last_updated_date }
      end

      private

      def report_params
        params.require(:report).permit(:template_id, :name, user_ids: [], accepted_accounting_class_ids: [], accepted_chart_of_account_ids: [])
      end

      def report_datas_params
        params.permit(:from, :to)
      end
    end
  end
end
