# frozen_string_literal: true

class RefillReportService < BaseService # rubocop:disable Metrics/ClassLength
  include DocytLib::Async::Publisher
  include DocytLib::Helpers::PerformanceHelpers

  def initialize(report:, start_date:, end_date:, period_type:, bookkeeping_start_date: nil, is_manual_update: false) # rubocop:disable Lint/MissingSuper, Metrics/ParameterLists
    @report = report
    @origin_start_date = start_date
    @start_date = start_date
    @end_date = end_date
    @period_type = period_type
    @bookkeeping_start_date = bookkeeping_start_date
    @is_manual_update = is_manual_update
    fetch_business_information(report.report_service)
  end

  def refill # rubocop:disable Metrics/MethodLength
    @start_date = start_date_for_update(report: @report, start_date: @start_date, period_type: @period_type)
    @end_date = end_date_for_update(end_date: @end_date, period_type: @period_type)
    cursor_date = find_and_process_report_datas_until_cursor
    if cursor_date <= @end_date
      refill_report_datas_asynchronously(cursor_date: cursor_date)
    else
      # We have nothing to update for the report
      publish(
        events.report_data_not_changed(
          report_id: @report.id.to_s,
          business_id: @report.report_service.business_id,
          report_template_id: @report.template_id,
          start_date: @start_date.strftime('%m/%d/%Y'),
          end_date: @end_date.strftime('%m/%d/%Y')
        )
      )
    end
  end
  apm_method :refill

  # This method fills item_values for report_datas
  def refill_report_data # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    @start_date = @start_date.to_date
    @end_date = @end_date.to_date
    data_start_date = monthly_update? ? Date.new(@start_date.year, @start_date.month, 1) : @start_date
    data_end_date = monthly_update? ? Date.new(@start_date.year, @start_date.month, -1) : @start_date
    report_data = @report.report_datas.new(start_date: data_start_date, end_date: data_end_date, period_type: @period_type)
    fill_report_data(report_data: report_data)
    if monthly_update? && !@report.missing_transactions_calculation_disabled
      Quickbooks::UnincludedLineItemDetailsFactory.create_for_report(
        report: @report,
        start_date: data_start_date, end_date: data_end_date,
        all_business_chart_of_accounts: @all_business_chart_of_accounts,
        accounting_classes: @accounting_classes
      )
    end
    do_after_finished_filling
  rescue MetricsServiceClient::ApiError, DocytServerClient::ApiError => e
    # We raise MetricsServiceClient::ApiError or DocytServerClient::ApiError to handle this exception in the ReportDataUpdaterWorker worker side.
    raise e
  rescue StandardError => e
    ReportFactory.handle_update_error(report: @report, error: e)
    report_data = ReportData.find_by(report: @report, start_date: @start_date, end_date: @end_date)
    report_data.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: e.message) if report_data.present?
  end
  apm_method :refill_report_data

  private

  def start_date_for_update(report:, start_date:, period_type:)
    @bookkeeping_start_date ||= fetch_bookkeeping_start_date(report.report_service)
    case period_type
    when ReportData::PERIOD_MONTHLY
      current_start_date = start_date.present? ? start_date.to_date : Date.new(@bookkeeping_start_date.year, 1, 1)
      [Date.new(@bookkeeping_start_date.year, 1, 1), current_start_date.at_beginning_of_month].max
    when ReportData::PERIOD_DAILY
      start_date.to_date
    end
  end

  def end_date_for_update(end_date:, period_type:)
    if period_type == ReportData::PERIOD_MONTHLY
      end_date = end_date.present? ? end_date.to_date : Time.zone.today
      end_date.end_of_month
    else
      end_date.to_date
    end
  end

  # In this case, we find the first report_data to update and set that to cursor_date
  def find_and_process_report_datas_until_cursor
    current_date = @start_date
    while current_date <= @end_date
      data_start_date = monthly_update? ? Date.new(current_date.year, current_date.month, 1) : current_date
      data_end_date = monthly_update? ? Date.new(current_date.year, current_date.month, -1) : current_date
      report_data = @report.report_datas.find_by(start_date: data_start_date, end_date: data_end_date, period_type: @period_type)
      break if report_data.nil? || report_data.should_update?

      report_data.update!(updated_at: Time.zone.now, update_state: Report::UPDATE_STATE_FINISHED, error_msg: nil)
      current_date += monthly_update? ? 1.month : 1.day
    end
    current_date
  end

  def refill_report_datas_asynchronously(cursor_date:)
    while cursor_date <= @end_date
      data_start_date = monthly_update? ? Date.new(cursor_date.year, cursor_date.month, 1) : cursor_date
      data_end_date = monthly_update? ? Date.new(cursor_date.year, cursor_date.month, -1) : cursor_date
      priority = @is_manual_update ? ReportFactory::MANUAL_UPDATE_PRIORITY : nil
      publish(
        events.refresh_report_data(report_id: @report.id.to_s, start_date: data_start_date.to_s, end_date: data_end_date.to_s, is_manual_update: @is_manual_update),
        priority: priority
      )
      cursor_date += monthly_update? ? 1.month : 1.day
    end
  end

  def fill_report_data(report_data:)
    ItemValueFactory.generate_batch(
      report_data: report_data, dependent_report_datas: report_data.dependent_report_datas,
      all_business_chart_of_accounts: @all_business_chart_of_accounts,
      accounting_classes: @accounting_classes
    )
    report_data.update_state = Report::UPDATE_STATE_FINISHED
    report_data.update_finished_at = Time.zone.now
    # Below line will take some time about 40 ~ 50ms. Because it will call metric service's internal api to recalc digest. So existed report data is deleted after recalc digest.
    report_data.recalc_digest
    report_data.report.report_datas.where(start_date: report_data.start_date, end_date: report_data.end_date).delete_all
    report_data.save!
  end

  def do_after_finished_filling
    refill_depends_on_reports if monthly_update?
    # Publishes event that report is updated for the range.
    publish(
      events.report_data_generated(
        report_id: @report.id.to_s,
        business_id: @report.report_service.business_id,
        report_template_id: @report.template_id,
        start_date: @start_date.strftime('%m/%d/%Y'),
        end_date: @end_date.strftime('%m/%d/%Y')
      )
    )
  end

  def refill_depends_on_reports
    reports = Report.where(report_service_id: @report.report_service_id)
    reports.each do |report|
      next unless report.dependent_template_ids.present? && report.dependent_template_ids.include?(@report.template_id)

      publish(events.refresh_report_data(report_id: report.id.to_s, start_date: @start_date.to_s, end_date: @end_date.to_s, is_manual_update: false))
    end
  end

  def daily_update?
    @period_type == ReportData::PERIOD_DAILY
  end

  def monthly_update?
    @period_type == ReportData::PERIOD_MONTHLY
  end
end
