# frozen_string_literal: true

module Api
  module V1
    class MultiBusinessReportsController < ApplicationController
      def create
        check_report_service_write_validations
        report_result = MultiBusinessReportFactory.create(current_user: secure_user, params: multi_business_report_params)
        if report_result.success?
          render status: :created, json: report_result.multi_business_report, serializer: ::MultiBusinessReportSerializer
        else
          render status: :unprocessable_entity, json: { errors: report_result.errors }
        end
      end

      def index
        multi_business_reports = MultiBusinessReportsQuery.new.multi_business_reports(current_user: secure_user)
        render status: :ok, json: multi_business_reports, each_serializer: ::MultiBusinessReportSerializer
      end

      def show
        ensure_multi_business_report(multi_business_report: multi_business_report)
        render status: :ok, json: multi_business_report, serializer: ::MultiBusinessReportSerializer
      end

      def update
        ensure_multi_business_report(multi_business_report: multi_business_report)
        report_result = MultiBusinessReportFactory.update_config(multi_business_report: multi_business_report, params: multi_business_report_params)
        if report_result.success?
          render status: :ok, json: multi_business_report.reload, serializer: ::MultiBusinessReportSerializer
        else
          render status: :unprocessable_entity, json: { errors: report_result.errors }
        end
      end

      def destroy
        ensure_multi_business_report(multi_business_report: multi_business_report)
        multi_business_report.destroy!
        render status: :ok, json: { success: true }
      end

      def update_report
        ensure_multi_business_report(multi_business_report: multi_business_report)
        report_result = MultiBusinessReportFactory.update_report(multi_business_report: multi_business_report)
        if report_result.success?
          render status: :ok, json: multi_business_report.reload, serializer: ::MultiBusinessReportSerializer
        else
          render status: :unprocessable_entity, json: { errors: report_result.errors }
        end
      end

      private

      def multi_business_report_params
        params.permit(:template_id, :name, report_service_ids: [])
      end

      def multi_business_report
        @multi_business_report ||= MultiBusinessReport.where(_id: params[:id]).first
      end

      def check_report_service_write_validations
        return if params[:report_service_ids].blank?

        params[:report_service_ids].each do |report_service_id|
          ensure_user_access(business_advisor_id: report_service_id, op: :write)
        end
      end
    end
  end
end
