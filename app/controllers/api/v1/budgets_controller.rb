# frozen_string_literal: true

module Api
  module V1
    class BudgetsController < ApplicationController
      def create
        ensure_report_service_access(report_service: report_service, operation: :write)
        result = BudgetFactory.create(current_user: secure_user, report_service: report_service, params: budget_params)
        if result.success?
          render status: :created, json: result.budget, serializer: ::BudgetWithMonthsSerializer, root: 'budget'
        else
          render status: :unprocessable_entity, json: { errors: result.errors }
        end
      end

      def update
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        current_budget.update!(name: params[:name], year: params[:year])
        render status: :ok, json: current_budget, serializer: ::BudgetWithMonthsSerializer, root: 'budget'
      end

      def index
        ensure_report_service_access(report_service: report_service, operation: :read)
        budgets = BudgetsQuery.new(report_service: report_service, params: budget_search_params).all_budgets
        render status: :ok, json: budgets, each_serializer: ::BudgetSerializer
      end

      def show
        ensure_report_service_access(report_service: current_budget.report_service, operation: :read)
        render status: :ok, json: current_budget, serializer: ::BudgetWithMonthsSerializer, root: 'budget'
      end

      def destroy
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        current_budget.destroy!
        render status: :ok, json: { success: true }
      end

      def by_ids
        ensure_report_service_access(report_service: report_service, operation: :read)
        budgets = report_service.budgets.where(_id: { '$in': params[:budget_ids] })
        render status: :ok, json: budgets, each_serializer: ::BudgetWithMonthsSerializer
      end

      def publish
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        current_budget.publish!
        render status: :ok, json: { success: true }
      end

      def discard
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        current_budget.discard!
        render status: :ok, json: { success: true }
      end

      private

      def current_budget
        Budget.find(params[:id])
      end

      def budget_params
        params.permit(:report_service_id, :year, :name)
      end

      def budget_search_params
        params.permit(:report_service_id, :order_column, :order_direction, :page)
      end
    end
  end
end
