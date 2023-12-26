# frozen_string_literal: true

module ExportExcel
  class BudgetExportService < ExportService
    def call(export_budget:)
      create_data_export(export_data: export_budget)
      export_result = export_budget(export_budget: export_budget)

      unless export_result.success?
        DocytLib.logger.error(export_result.errors)
        update_data_export(state: DATA_EXPORT_ERROR_STATE)
        return
      end
      exported_file_token = upload_file(filename: File.basename(export_result.report_file_path), source_file: File.read(export_result.report_file_path))
      return if exported_file_token.blank?

      update_data_export(exported_file_token: exported_file_token)
    end

    private

    def export_budget(export_budget:)
      budget = Budget.find(export_budget.budget_id)
      ExportExcel::ExportBudgetDataService.call(budget: budget, start_date: export_budget.start_date, end_date: export_budget.end_date, filter: export_budget.filter)
    end
  end
end
