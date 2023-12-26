# frozen_string_literal: true

module Api
  module V1
    class ReportServicesController < ApplicationController
      def by_business_id
        report_service = ReportService.find_by(business_id: params[:business_id])
        ensure_report_service_access(report_service: report_service, operation: :read)
        render status: :ok, json: report_service, serializer: ::ReportServiceSerializer
      end

      def update_default_budget
        ensure_report_service_access(report_service: report_service, operation: :write)
        default_budget = report_service.budgets.find_by(id: params[:default_budget_id])
        report_service.update!(default_budget: default_budget)
        render status: :ok, json: report_service, serializer: ::ReportServiceSerializer
      end
    end
  end
end
