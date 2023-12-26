# frozen_string_literal: true

module Docyt
  module Workers
    class ReportServiceDeleteWorker
      include DocytLib::Async::Worker

      subscribe :report_service_deleted

      def perform(event)
        deactivate_report_service(event[:business_id])
      end

      private

      def deactivate_report_service(business_id)
        report_service = ReportService.find_by(business_id: business_id)
        return if report_service.blank?

        report_service.update!(active: false)
      end
    end
  end
end
