# frozen_string_literal: true

class BaseReportDataUpdateFactory < BaseService
  class QuickbooksIsNotConnectedError < StandardError; end

  include DocytLib::Helpers::PerformanceHelpers
  include DocytLib::Async::Publisher

  private

  def handle_error(obj, error)
    err_msg = case error
              when QuickbooksIsNotConnectedError
                Report::ERROR_MSG_QBO_NOT_CONNECTED
              when OAuth2::Error
                Quickbooks::Error.error_message(error: error)
              else
                'Unexpected error.'
              end

    obj.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: err_msg)
  end

  def fetch_general_ledgers_for_monthly_update(report_service:, bookkeeping_start_date:, qbo_authorization:, period_start_date: nil, period_end_date: nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    period_start_date ||= Date.new(bookkeeping_start_date.year, 1, 1)
    # We now calculate the prior year values from the general ledgers and thus we need 1 year ago general ledger.
    period_start_date = [Date.new(bookkeeping_start_date.year, 1, 1), period_start_date - 1.year].max
    period_end_date ||= Time.zone.today
    fetch_balance_sheet(report_service: report_service, date: period_start_date - 1.month, qbo_authorization: qbo_authorization)
    current_date = Date.new(period_start_date.year, period_start_date.month, 1)
    while current_date <= period_end_date
      start_date = Date.new(current_date.year, current_date.month, 1)
      end_date = Date.new(current_date.year, current_date.month, -1)
      current_date += 1.month
      fetch_general_ledger(report_service: report_service, start_date: start_date, end_date: end_date, qbo_authorization: qbo_authorization)
      break if current_date > Time.zone.today

      qbo_authorization = Quickbooks::GeneralLedgerImporter.fetch_qbo_token(report_service)
    end
    report_service.update!(ledgers_imported_at: Time.zone.now)
  end

  def fetch_balance_sheet(report_service:, date:, qbo_authorization:)
    start_date = Date.new(date.year, date.month, 1)
    end_date = Date.new(date.year, date.month, -1)
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::BalanceSheetGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
  end

  def fetch_general_ledger(report_service:, start_date:, end_date:, qbo_authorization:) # rubocop:disable Metrics/MethodLength
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::BalanceSheetGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
    Quickbooks::GeneralLedgerImporter.import(
      report_service: report_service,
      general_ledger_class: Quickbooks::CommonGeneralLedger,
      start_date: start_date, end_date: end_date,
      qbo_authorization: qbo_authorization
    )
  end
end
