# frozen_string_literal: true

class ReportsInReportServiceUpdater < BaseReportDataUpdateFactory
  def update_all_reports(report_service) # rubocop:disable Metrics/MethodLength
    qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
    raise BaseReportDataUpdateFactory::QuickbooksIsNotConnectedError unless qbo_authorization

    bookkeeping_start_date = fetch_bookkeeping_start_date(report_service)
    fetch_general_ledgers_for_monthly_update(report_service: report_service, bookkeeping_start_date: bookkeeping_start_date, qbo_authorization: qbo_authorization)
    report_service.reports.each do |report|
      report.update!(update_state: Report::UPDATE_STATE_QUEUED)
      # We synchronize report infos every day.
      report_factory_class = report.factory_class
      report_factory_class.sync_report_infos(report: report)
      next if report.dependent_template_ids.present?

      refill_service = RefillReportService.new(
        report: report, period_type: ReportData::PERIOD_MONTHLY,
        start_date: nil, end_date: nil,
        bookkeeping_start_date: bookkeeping_start_date,
        is_manual_update: false
      )
      refill_service.refill
    end
    report_service.update!(updated_at: Time.zone.now)
  rescue StandardError => e
    report_service.reports.map do |report|
      handle_error(report, e)
    end
    Rollbar.error(e)
  end
  apm_method :update_all_reports

  def update_report(report:) # rubocop:disable Metrics/MethodLength
    qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report.report_service)
    raise BaseReportDataUpdateFactory::QuickbooksIsNotConnectedError unless qbo_authorization

    bookkeeping_start_date = fetch_bookkeeping_start_date(report.report_service)
    fetch_general_ledgers_for_monthly_update(report_service: report.report_service, bookkeeping_start_date: bookkeeping_start_date, qbo_authorization: qbo_authorization)
    report_factory_class = report.factory_class
    report_factory_class.sync_report_infos(report: report)
    refill_service = RefillReportService.new(
      report: report, period_type: ReportData::PERIOD_MONTHLY,
      start_date: nil, end_date: nil,
      bookkeeping_start_date: bookkeeping_start_date,
      is_manual_update: true
    )
    refill_service.refill
    report.update!(updated_at: Time.zone.now, update_state: Report::UPDATE_STATE_FINISHED, error_msg: nil)
  rescue StandardError => e
    handle_error(report, e)
    Rollbar.error(e)
  end
  apm_method :update_report
end
