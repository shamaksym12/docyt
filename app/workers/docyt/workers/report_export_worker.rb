# frozen_string_literal: true

module Docyt
  module Workers
    class ReportExportWorker
      include DocytLib::Async::Worker
      subscribe :export_report_requested
      prefetch 1

      def perform(event)
        export_report = ExportReport.find(event[:export_report_id])
        ExportExcel::ReportExportService.call(export_report: export_report)
      end
    end
  end
end
