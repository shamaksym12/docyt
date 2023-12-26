# frozen_string_literal: true

module Docyt
  module Workers
    class AccountingClassDestroyWorker
      include DocytLib::Async::Worker

      subscribe :accounting_class_destroyed

      def perform(event)
        destroy_item_accounts(business_id: event[:business_id], accounting_class_id: event[:accounting_class_id])
      end

      private

      def destroy_item_accounts(business_id:, accounting_class_id:) # rubocop:disable Metrics/MethodLength
        report_service = ReportService.find_by(business_id: business_id)
        return if report_service.blank?

        report_service.reports.each do |report|
          report.all_item_accounts.each do |item_account|
            if item_account.accounting_class_id == accounting_class_id
              if report.departmental_report?
                item_account.item.destroy!
              else
                item_account.destroy!
              end
            end
          end
        end
      end
    end
  end
end
