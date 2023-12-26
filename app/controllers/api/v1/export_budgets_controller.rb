# frozen_string_literal: true

module Api
  module V1
    class ExportBudgetsController < ApplicationController
      def create
        budget = Budget.find_by(id: params[:budget_id])
        ensure_report_service_access(report_service: budget.report_service, operation: :read)

        ExportBudgetFactory.create(export_params: export_budget_params, secure_user: secure_user, budget: budget)

        render status: :created, json: { success: true }
      end

      private

      def export_budget_params
        params.permit(:start_date, :end_date, filter: {})
      end
    end
  end
end
