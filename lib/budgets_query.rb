# frozen_string_literal: true

class BudgetsQuery < BaseService
  BUDGETS_PER_PAGE = 20

  def initialize(report_service:, params:)
    super()
    @params = params
    @report_service = report_service
    @order_column = params[:order_column] || 'created_at'
    @order_direction = params[:order_direction] || 'desc'
    @page = params[:page] || 1
    @per_page = params[:per] || BUDGETS_PER_PAGE
  end

  def all_budgets
    query = @report_service.budgets
    budgets = common_query(query)
    users = get_users(user_ids: budgets.map(&:creator_id))
    BudgetsDecorator.decorate_collection(budgets, context: { users: users })
  end

  private

  def common_query(query)
    query.order_by([@order_column, @order_direction]).page(@page).per(@per_page)
  end
end
