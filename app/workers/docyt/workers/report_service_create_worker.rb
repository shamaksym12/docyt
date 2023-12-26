# frozen_string_literal: true

module Docyt
  module Workers
    class ReportServiceCreateWorker
      include DocytLib::Async::Worker
      include DocytLib::Async::Publisher

      subscribe :report_service_created

      def perform(event)
        create_report_service(event[:business_id], event[:report_service_id])
      end

      private

      def create_report_service(business_id, report_service_id)
        report_service = ReportService.find_by(business_id: business_id)
        return if report_service.present?

        report_service = ReportService.create!(
          service_id: report_service_id,
          business_id: business_id,
          active: true
        )
        sync_report_service(report_service: report_service)
      end

      def sync_report_service(report_service:)
        Report.where(docyt_service_id: report_service.service_id).each do |report|
          report.update!(report_service: report_service)
        end
        ProfitAndLossReportFactory.create(report_service: report_service)
        BalanceSheetReportFactory.create(report_service: report_service)
        publish(events.refresh_report_datas(report_service_id: report_service.id.to_s))
      end
    end
  end
end
