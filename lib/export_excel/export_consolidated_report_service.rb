# frozen_string_literal: true

module ExportExcel
  class ExportConsolidatedReportService < ExportReportDataService
    def call(report_service:, reports:, start_date:, end_date:)
      @start_date = start_date
      @end_date = end_date
      @reports = reports
      @business = get_business(report_service)
      @last_reconciled_date = Date.new(@business.last_reconciled_month_data.year, @business.last_reconciled_month_data.month) if @business.last_reconciled_month_data
      generate_axlsx(report_name_prefix: "#{@business.name}-report-")
    end

    private

    def fill_work_book(work_book:)
      @reports.each do |report|
        @report = report
        report_datas_params = { from: @start_date, to: @end_date }
        report_data_query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: false)
        monthly_report_datas = report_data_query.report_datas
        next if monthly_report_datas.blank?

        name = report.name.gsub(/[^ 0-9A-Za-z'-.,]/, '_')
        name = name.length > 30 ? "#{name[0..27]}..." : name
        add_monthly_sheet(work_book: work_book, report_data: monthly_report_datas.first, name: name)
      end
    end
  end
end
