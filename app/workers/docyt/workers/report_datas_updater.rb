# frozen_string_literal: true

module Docyt
  module Workers
    class ReportDatasUpdater
      include DocytLib::Async::Worker
      include DocytLib::Async::Publisher
      subscribe :refresh_report_datas
      # This is a slow worker therefore we need to avoid prefetching too many messages to make sure that priorities are working correctly
      prefetch 1

      GENERAL_LEDGER_UPDATE_MAXIMUM_TIME = 600_000
      DELAY_FOR_RESCHEDULE_TIME = 10_000

      def perform(event)
        report_service = ReportService.find(event[:report_service_id])
        if event[:start_date].present? && event[:end_date].present?
          handle_refresh_report_datas(event: event, report_service: report_service)
        elsif event[:report_id].present?
          handle_refresh_report(event: event, report_service: report_service)
        else
          handle_refresh_report_service(report_service)
        end
      end

      private

      def handle_refresh_report_service(report_service)
        DocytLib.logger.info("Worker for ReportData started, Report Service ID: #{report_service.id}")
        lock_report_service(report_service) do
          ReportsInReportServiceUpdater.update_all_reports(report_service)
          DocytLib.logger.info("Worker successfully performed running, Report Service ID: #{report_service.id}.")
        end
      rescue DocytLib::Locking::LockError
        publish(events.refresh_report_datas(report_service_id: report_service.id.to_s), delay_milliseconds: DELAY_FOR_RESCHEDULE_TIME)
        DocytLib.logger.info("Worker successfully re-scheduled, Report Service ID: #{report_service.id}.")
      end

      def handle_refresh_report(event:, report_service:)
        report = Report.find(event[:report_id])
        DocytLib.logger.info("Worker for ReportData started, Report ID: #{event[:report_id]}")
        lock_report_service(report_service) do
          ReportsInReportServiceUpdater.update_report(report: report)
          DocytLib.logger.info("Worker successfully performed running, Report ID: #{event[:report_id]}.")
        end
      rescue DocytLib::Locking::LockError
        ReportFactory.enqueue_report_update(report: report, delay_milliseconds: DELAY_FOR_RESCHEDULE_TIME)
        DocytLib.logger.info("Worker successfully re-scheduled, Report ID: #{event[:report_id]}.")
      end

      def handle_refresh_report_datas(event:, report_service:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        DocytLib.logger.info("Worker for Report started, Report ID: #{event[:report_id]}, From: #{event[:start_date]}, To: #{event[:end_date]}, Type: #{event[:period_type]}")
        report = Report.find(event[:report_id])
        lock_report_service(report_service) do
          ReportDatasUpdateFactory.update(report: report, start_date: event[:start_date].to_date, end_date: event[:end_date].to_date, period_type: event[:period_type])
          DocytLib.logger.info("Worker successfully performed running, Report ID: #{event[:report_id]}.")
        end
      rescue DocytLib::Locking::LockError
        reschedule_update_report_datas(event)
        DocytLib.logger.info(
          "Worker successfully re-scheduled, Report ID: #{event[:report_id]}, From: #{event[:start_date]}, To: #{event[:end_date]}, Type: #{event[:period_type]}."
        )
      end

      def reschedule_update_report_datas(event)
        publish(
          events.refresh_report_datas(
            report_service_id: event[:report_service_id], report_id: event[:report_id],
            start_date: event[:start_date], end_date: event[:end_date],
            period_type: event[:period_type]
          ),
          delay_milliseconds: DELAY_FOR_RESCHEDULE_TIME,
          priority: ReportFactory::MANUAL_UPDATE_PRIORITY
        )
      end

      def lock_report_service(report_service, &block)
        lock_key = "fetch_general_ledger_for_service_#{report_service.id}"
        DocytLib.lock_manager.lock!(lock_key, GENERAL_LEDGER_UPDATE_MAXIMUM_TIME, &block)
      end
    end
  end
end
