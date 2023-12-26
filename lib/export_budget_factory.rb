# frozen_string_literal: true

class ExportBudgetFactory < BaseService
  def create(export_params:, secure_user:, budget:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    filter = {}
    filter['account_type'] = export_params[:filter][:account_type] if export_params[:filter][:account_type]
    filter['accounting_class_id'] = export_params[:filter][:accounting_class_id].to_i if export_params[:filter][:accounting_class_id]
    filter['chart_of_account_display_name'] = export_params[:filter][:chart_of_account_display_name] if export_params[:filter][:chart_of_account_display_name]
    filter['hide_blank'] = export_params[:filter][:hide_blank] if export_params[:filter][:hide_blank]

    export_budget = ExportBudget.create!(
      user_id: secure_user.id,
      start_date: export_params[:start_date],
      end_date: export_params[:end_date],
      filter: filter,
      budget_id: budget.id
    )

    export_budget.request_export_budget
  end
end
