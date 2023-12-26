# frozen_string_literal: true

module ExportExcel
  class ReportExportService < ExportService
    def call(export_report:) # rubocop:disable Metrics/MethodLength
      create_data_export(export_data: export_report)
      report_result = case export_report.export_type
                      when ExportReport::EXPORT_TYPE_REPORT
                        export_report_as_excel(export_report: export_report)
                      when ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT
                        export_multi_entity_report(export_report: export_report)
                      else
                        export_consolidated_report(export_report: export_report)
                      end
      unless report_result.success?
        DocytLib.logger.error(report_result.errors)
        update_data_export(state: DATA_EXPORT_ERROR_STATE)
        return
      end
      exported_file_token = upload_file(filename: File.basename(report_result.report_file_path), source_file: File.read(report_result.report_file_path))
      return if exported_file_token.blank?

      update_data_export(exported_file_token: exported_file_token)
    end

    private

    def export_report_as_excel(export_report:)
      report = Report.find(export_report.report_id)
      if report.departmental_report?
        ExportExcel::ExportDepartmentReportDataService.call(report: report,
                                                            start_date: export_report.start_date, end_date: export_report.end_date,
                                                            filter: export_report.filter)
      elsif export_report.start_date == export_report.end_date
        ExportExcel::ExportDailyReportDataService.call(report: report, current_date: export_report.start_date, filter: export_report.filter)
      else
        ExportExcel::ExportReportDataService.call(report: report, start_date: export_report.start_date, end_date: export_report.end_date, filter: export_report.filter)
      end
    end

    def export_multi_entity_report(export_report:)
      multi_business_report = MultiBusinessReport.find(export_report.multi_business_report_id)
      ExportExcel::ExportMultiBusinessReportDataService.call(multi_business_report: multi_business_report,
                                                             start_date: export_report.start_date, end_date: export_report.end_date, filter: export_report.filter)
    end

    def export_consolidated_report(export_report:)
      report_service = ReportService.find(export_report.report_service_id)
      reports = AdvancedReport.where(report_service: report_service).all
      ExportExcel::ExportConsolidatedReportService.call(report_service: report_service, reports: reports,
                                                        start_date: export_report.start_date, end_date: export_report.end_date)
    end
  end
end
