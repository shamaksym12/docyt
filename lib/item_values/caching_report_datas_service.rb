# frozen_string_literal: true

module ItemValues
  class CachingReportDatasService
    def initialize(report_service)
      @report_service = report_service
      @cache = {}
    end

    def get(report:, start_date:, end_date:)
      @cache[report.id.to_s] ||= {}
      cached_report_data(report: report, start_date: start_date, end_date: end_date)
    end

    private

    def cached_report_data(report:, start_date:, end_date:)
      pointer_str = start_date.strftime('%m/%d/%Y')
      @cache[report.id.to_s][pointer_str] ||= ReportData.find_by(
        report: report,
        start_date: start_date,
        end_date: end_date
      )
    end
  end
end
