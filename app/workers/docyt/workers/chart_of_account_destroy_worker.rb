# frozen_string_literal: true

module Docyt
  module Workers
    class ChartOfAccountDestroyWorker
      include DocytLib::Async::Worker

      subscribe :business_chart_of_account_destroyed

      def perform(event)
        destroy_item_accounts(business_id: event[:business_id], chart_of_account_id: event[:chart_of_account_id])
      end

      private

      def destroy_item_accounts(business_id:, chart_of_account_id:)
        report_service = ReportService.find_by(business_id: business_id)
        return if report_service.blank?

        report_service.reports.each do |report|
          report.all_item_accounts.each do |item_account|
            item_account.destroy! if item_account.chart_of_account_id == chart_of_account_id
          end
        end
      end
    end
  end
end
