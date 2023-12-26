# frozen_string_literal: true

class BudgetItemsQuery < BaseService
  BUDGET_ITEMS_PER_PAGE = 50

  attr_reader :params, :filters

  def initialize(current_budget:, params:)
    super()
    @current_budget = current_budget
    @params = params
    @filters = params[:filter] || {}
    @page = params[:page] || 1
    @per_page = params[:per] || BUDGET_ITEMS_PER_PAGE
    fetch_business_chart_of_accounts
    @budget_items_query = apply_filters(@current_budget.draft_budget_items)
  end

  def all_budget_items
    @budget_items_query.order_by(position: :asc)
  end

  def budget_items
    @budget_items_query.order_by(position: :asc).page(@page).per(@per_page)
  end

  def month_total_amounts
    amounts = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    @budget_items_query.each do |item|
      next if item.standard_metric_id

      item.budget_item_values.each do |value|
        amounts[value.month - 1] += value.value
      end
    end
    amounts
  end

  private

  def apply_filters(query)
    unless @filters[:chart_of_account_display_name].blank? && @filters[:account_type].blank?
      query = query.where(:chart_of_account_id.in => @business_chart_of_accounts.map(&:chart_of_account_id) + [nil])
    end
    query = query.where(:accounting_class_id.in => [@filters[:accounting_class_id], nil]) if @filters[:accounting_class_id].present?
    query = query.any_of({ is_blank: false }, { chart_of_account_id: nil }) if @filters[:hide_blank].present? && @filters[:hide_blank] == 'true'
    query
  end

  def fetch_business_chart_of_accounts
    return if @filters[:chart_of_account_display_name].blank? && @filters[:account_type].blank?

    display_name = @filters[:chart_of_account_display_name].presence || ''
    acc_type = @filters[:account_type].presence || ''
    fetch_business_chart_of_accounts_by_params(business_id: @current_budget.report_service.business_id, display_name: display_name, acc_type: acc_type)
  end
end
