# frozen_string_literal: true

module Docyt
  module Workers
    class ReportDataUpdater
      include DocytLib::Async::Worker
      include DocytLib::Async::Publisher

      subscribe :refresh_report_data
      prefetch 1

      SERVER_DELAY_TIME = 300_000
      SERVER_ERROR_CODES = (501..504).freeze
      REPORT_DATA_UPDATE_MAXIMUM_TIME = 300_000
      DELAY_FOR_RESCHEDULE_TIME = 10_000

      def perform(event) # rubocop:disable Metrics/MethodLength
        report = Report.find(event[:report_id])
        return if report.nil?
        return unless check_if_report_data_updatable?(report: report, event: event)

        DocytLib.logger.info("Worker started, Report ID: #{report.id}, Start Date: #{event[:start_date]}, End Date: #{event[:end_date]}")
        lock_key = "update_report_data_#{report.id}_#{event[:start_date]}_#{event[:end_date]}"
        DocytLib.lock_manager.lock!(lock_key, REPORT_DATA_UPDATE_MAXIMUM_TIME) do
          update_report_for_range(report: report, event: event)
        end
        DocytLib.logger.info("Worker finished. Report ID: #{report.id}, Start Date: #{event[:start_date]}, End Date: #{event[:end_date]}")
      rescue DocytLib::Locking::LockError
        enqueue_event_again(event: event, delay_milliseconds: DELAY_FOR_RESCHEDULE_TIME)
      end

      private

      def update_report_for_range(report:, event:) # rubocop:disable Metrics/MethodLength
        refill_service = RefillReportService.new(
          report: report,
          start_date: event[:start_date], end_date: event[:end_date],
          period_type: period_type(event: event),
          is_manual_update: event[:is_manual_update]
        )
        refill_service.refill_report_data
      rescue MetricsServiceClient::ApiError, DocytServerClient::ApiError => e
        if SERVER_ERROR_CODES.include?(e.code.to_i)
          enqueue_event_again(event: event, delay_milliseconds: SERVER_DELAY_TIME)
        else
          ReportFactory.handle_update_error(report: report, error: e)
          report_data = ReportData.find_by(report: report, start_date: event[:start_date], end_date: event[:end_date])
          report_data.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: e.message) if report_data.present?
        end
      end

      def period_type(event:)
        if event[:start_date] == event[:end_date]
          ReportData::PERIOD_DAILY
        else
          ReportData::PERIOD_MONTHLY
        end
      end

      def enqueue_event_again(event:, delay_milliseconds:)
        priority = event[:is_manual_update] ? ReportFactory::MANUAL_UPDATE_PRIORITY : nil
        publish(
          events.refresh_report_data(
            report_id: event[:report_id],
            start_date: event[:start_date].to_s, end_date: event[:end_date].to_s,
            is_manual_update: event[:is_manual_update]
          ),
          delay_milliseconds: delay_milliseconds,
          priority: priority
        )
      end

      def check_if_report_data_updatable?(report:, event:)
        report_data = ReportData.find_by(report: report, start_date: event[:start_date], end_date: event[:end_date])
        updatable = report_data.nil? || report_data.should_update?
        unless updatable
          publish(events.report_data_not_changed(report_id: report.id.to_s, business_id: report.report_service.business_id, report_template_id: report.template_id,
                                                 start_date: report_data.start_date.strftime('%m/%d/%Y'), end_date: report_data.end_date.strftime('%m/%d/%Y')))
        end
        updatable
      end
    end
  end
end
