# frozen_string_literal: true

class BudgetItemFactory
  include DocytLib::Utils::DocytInteractor

  def upsert_item(current_budget:, budget_item_params:)
    budget_item = current_budget.draft_budget_items.find(budget_item_params[:id])
    BudgetItemValueFactory.upsert_batch(budget_item: budget_item, budget_item_values: budget_item_params[:budget_item_values])
    current_budget.status = Budget::STATE_DRAFT unless current_budget.status == Budget::STATE_DRAFT
    current_budget.save!
  end

  def auto_fill_items(current_budget:, params:)
    if params[:clear].blank?
      qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(current_budget.report_service)
      add_error('QuickBooks is not connected.') and return if qbo_authorization.nil?
    end

    AutoFillBudgetService.new(
      budget: current_budget,
      params: params
    ).perform
  end
end
