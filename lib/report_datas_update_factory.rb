# frozen_string_literal: true

class ReportDatasUpdateFactory < BaseReportDataUpdateFactory
  def update(report:, start_date:, end_date:, period_type:) # rubocop:disable Metrics/MethodLength
    bookkeeping_start_date = fetch_bookkeeping_start_date(report.report_service)
    qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report.report_service)
    raise BaseReportDataUpdateFactory::QuickbooksIsNotConnectedError unless qbo_authorization

    fetch_general_ledgers(
      report: report, qbo_authorization: qbo_authorization,
      start_date: start_date, end_date: end_date,
      period_type: period_type, bookkeeping_start_date: bookkeeping_start_date
    )
    report_factory_class = report.factory_class
    report_factory_class.sync_report_infos(report: report)
    refill_service = RefillReportService.new(
      report: report, period_type: period_type,
      start_date: start_date, end_date: end_date,
      bookkeeping_start_date: bookkeeping_start_date,
      is_manual_update: true
    )
    refill_service.refill
  rescue StandardError => e
    find_or_create_report_datas_with_error(report: report, start_date: start_date, end_date: end_date, period_type: period_type, error: e)
    Rollbar.error(e)
  end

  private

  def fetch_general_ledgers(report:, qbo_authorization:, start_date:, end_date:, period_type:, bookkeeping_start_date:) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    start_date_for_fetch = start_date.at_beginning_of_year
    if period_type == ReportData::PERIOD_MONTHLY
      fetch_general_ledgers_for_monthly_update(
        report_service: report.report_service,
        bookkeeping_start_date: bookkeeping_start_date, qbo_authorization: qbo_authorization,
        period_start_date: start_date_for_fetch, period_end_date: end_date
      )
    else
      fetch_general_ledgers_for_daily_update(
        report_service: report.report_service, qbo_authorization: qbo_authorization,
        current_date: start_date
      )
    end
  end

  def find_or_create_report_datas_with_error(report:, start_date:, end_date:, period_type:, error:) # rubocop:disable Metrics/MethodLength
    current_start_date = [Date.new(@bookkeeping_start_date.year, 1, 1), start_date].max
    while current_start_date <= end_date
      current_end_date = (period_type == Report::PERIOD_MONTHLY ? current_start_date.end_of_month : current_start_date)
      report_data = report.report_datas.find_or_create_by!(start_date: current_start_date, end_date: current_end_date, period_type: period_type)
      handle_error(report_data, error)
      current_start_date += (period_type == Report::PERIOD_MONTHLY ? 1.month : 1.day)
    end
    # Publishes event that report is not updated.
    publish(
      events.report_data_not_changed(
        report_id: report.id.to_s,
        business_id: report.report_service.business_id,
        report_template_id: report.template_id,
        start_date: start_date.strftime('%m/%d/%Y'),
        end_date: end_date.strftime('%m/%d/%Y')
      )
    )
  end

  def fetch_general_ledgers_for_daily_update(report_service:, qbo_authorization:, current_date:) # rubocop:disable Metrics/MethodLength
    ::Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: ::Quickbooks::CommonGeneralLedger,
      start_date: current_date.at_beginning_of_month,
      end_date: current_date.at_end_of_month,
      qbo_authorization: qbo_authorization
    )
    ::Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
      start_date: current_date,
      end_date: current_date,
      qbo_authorization: qbo_authorization
    )
    ::Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
      start_date: current_date - 1.day,
      end_date: current_date - 1.day,
      qbo_authorization: qbo_authorization
    )
    prior_month_start_date = (current_date - 1.month).at_beginning_of_month
    ::Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: ::Quickbooks::BalanceSheetGeneralLedger,
      start_date: prior_month_start_date,
      end_date: prior_month_start_date.at_end_of_month,
      qbo_authorization: qbo_authorization
    )
  end
end
