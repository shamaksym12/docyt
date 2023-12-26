# frozen_string_literal: true

module Quickbooks
  class UnincludedLineItemDetailsFactory < BaseService
    def create_for_report(report:, start_date:, end_date:, all_business_chart_of_accounts:, accounting_classes:)
      @all_business_chart_of_accounts = all_business_chart_of_accounts
      @accounting_classes = accounting_classes
      generate_unincluded_line_item_details(report: report, start_date: start_date, end_date: end_date)
    end

    private

    def generate_unincluded_line_item_details(report:, start_date:, end_date:) # rubocop:disable Metrics/MethodLength
      report.unincluded_line_item_details.where(transaction_date: { '$gte' => start_date, '$lte' => end_date }).destroy_all
      return if report.accepted_chart_of_account_ids.blank? || report.accepted_accounting_class_ids.blank?

      item_accounts = report.all_item_accounts
      line_item_details = []
      common_general_ledgers = Quickbooks::CommonGeneralLedger.where(report_service: report.report_service)
      common_general_ledgers = common_general_ledgers.where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
      common_general_ledgers.each do |general_ledger|
        line_item_details += generate_unincluded_line_item_details_for_general_ledger(report: report, general_ledger: general_ledger, item_accounts: item_accounts)
      end
      return if line_item_details.empty?

      report.unincluded_line_item_details.collection.insert_many(line_item_details)
    end

    def generate_unincluded_line_item_details_for_general_ledger(report:, general_ledger:, item_accounts:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      all_line_item_details = general_ledger.line_item_details
      item_accounts.each do |item_account|
        business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == item_account.chart_of_account_id }.first
        next if business_chart_of_account.nil?

        accounting_class = @accounting_classes.select { |business_accounting_class| business_accounting_class.id == item_account.accounting_class_id }.first
        next if item_account.accounting_class_id.present? && accounting_class.nil?

        all_line_item_details.reject! { |lid| lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id && lid.accounting_class_qbo_id == accounting_class&.external_id }
        break if all_line_item_details.length.zero?
      end
      line_item_details_array(report: report, line_item_details: all_line_item_details)
    end

    def line_item_details_array(report:, line_item_details:) # rubocop:disable Metrics/MethodLength
      line_item_details_array = []
      line_item_details.each do |line_item_detail|
        next unless unincluded_line_item_detail?(report: report, line_item_detail: line_item_detail)

        line_item_details_array << {
          report_id: report.id,
          amount: line_item_detail.amount,
          transaction_date: line_item_detail.transaction_date,
          transaction_type: line_item_detail.transaction_type,
          transaction_number: line_item_detail.transaction_number,
          memo: line_item_detail.memo,
          vendor: line_item_detail.vendor,
          split: line_item_detail.split,
          qbo_id: line_item_detail.qbo_id,
          category: line_item_detail.category,
          accounting_class: line_item_detail.accounting_class,
          chart_of_account_qbo_id: line_item_detail.chart_of_account_qbo_id,
          accounting_class_qbo_id: line_item_detail.accounting_class_qbo_id
        }
      end
      line_item_details_array
    end

    def unincluded_line_item_detail?(report:, line_item_detail:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return false if line_item_detail.amount.blank?

      business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.qbo_id == line_item_detail.chart_of_account_qbo_id }
      return false if business_chart_of_account.nil?

      accepted_chart_of_account = report.accepted_chart_of_account_ids.detect do |accepted_chart_of_account_id|
        accepted_chart_of_account_id == business_chart_of_account.chart_of_account_id
      end
      return false if accepted_chart_of_account.blank?

      accounting_class = @accounting_classes.detect { |category| category.external_id == line_item_detail.accounting_class_qbo_id }
      return false if line_item_detail.accounting_class_qbo_id.present? && accounting_class.nil?

      return false unless report.accepted_accounting_class_ids.include?(accounting_class&.id.to_i)

      true
    end
  end
end
