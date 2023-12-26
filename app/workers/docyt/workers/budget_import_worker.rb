# frozen_string_literal: true

module Docyt
  module Workers
    class BudgetImportWorker
      include DocytLib::Async::Worker
      subscribe :import_budget_requested
      prefetch 1

      def perform(event)
        import_budget = ImportBudget.find(event[:import_budget_id])
        ImportExcel::BudgetImportService.call(import_budget: import_budget)
      end
    end
  end
end
