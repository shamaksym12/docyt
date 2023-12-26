# frozen_string_literal: true

module Docyt
  module Workers
    class BudgetExportWorker
      include DocytLib::Async::Worker
      subscribe :export_budget_requested
      prefetch 1

      def perform(event)
        export_budget = ExportBudget.find(event[:export_budget_id])
        ExportExcel::BudgetExportService.call(export_budget: export_budget)
      end
    end
  end
end
