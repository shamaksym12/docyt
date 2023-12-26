# frozen_string_literal: true

class ImportBudgetFactory < BaseService
  def create(import_params:, secure_user:, budget:)
    import_budget = ImportBudget.create!(
      user_id: secure_user.id,
      budget_id: budget.id
    )

    import_budget.update!(imported_file_token: import_params[:file_token])

    import_budget.request_import_budget
  end
end
