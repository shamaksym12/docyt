# frozen_string_literal: true

module Api
  module V1
    class BudgetItemsController < ApplicationController
      def index
        ensure_report_service_access(report_service: current_budget.report_service, operation: :read)
        budget_items_query_instance = BudgetItemsQuery.new(current_budget: current_budget, params: budget_items_search_params)
        budget_items = budget_items_query_instance.budget_items
        month_total_amounts = budget_items_query_instance.month_total_amounts
        render status: :ok, json: budget_items, each_serializer: ::BudgetItemSerializer,
               meta: { month_total_amounts: month_total_amounts }
      end

      # This api endpoint upsert draft_budget_item
      def upsert
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        result = BudgetItemFactory.upsert_item(current_budget: current_budget, budget_item_params: budget_item_params)
        if result.success?
          render status: :ok, json: { success: true }
        else
          render status: :unprocessable_entity, json: { errors: result.errors }
        end
      end

      def auto_fill
        ensure_report_service_access(report_service: current_budget.report_service, operation: :write)
        result = BudgetItemFactory.auto_fill_items(current_budget: current_budget, params: auto_fill_params)
        if result.success?
          render status: :ok, json: { success: true }
        else
          render status: :unprocessable_entity, json: { errors: result.errors }
        end
      end

      private

      def current_budget
        @current_budget ||= Budget.find(params[:budget_id])
      end

      def budget_items_search_params
        params.permit(:page, :per, filter: {})
      end

      def budget_item_params
        params.permit(:id, budget_item_values: %i[month value])
      end

      def auto_fill_params
        params.permit(:business_id, :year, :increase, :clear, months: [], budget_item_ids: [])
      end
    end
  end
end
