# frozen_string_literal: true

module Api
  module V1
    class ImportBudgetsController < ApplicationController
      def create
        budget = Budget.find_by(id: params[:budget_id])
        ensure_report_service_access(report_service: budget.report_service, operation: :read)

        ImportBudgetFactory.create(import_params: import_budget_params, secure_user: secure_user, budget: budget)

        render status: :created, json: { success: true }
      end

      private

      def import_budget_params
        params.permit(:file_token)
      end
    end
  end
end
