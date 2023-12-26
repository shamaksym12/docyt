# frozen_string_literal: true

class MigrateToAcceptedChartOfAccountsService < BaseService
  def migrate(report:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    accepted_chart_of_account_ids = []

    fetch_all_business_chart_of_accounts(business_id: report.report_service.business_id)
    return if @all_business_chart_of_accounts.count.zero?

    report.accepted_account_types.each do |accepted_account_type|
      chart_of_accounts = @all_business_chart_of_accounts.filter do |chart_of_account|
        chart_of_account.acc_type_name == accepted_account_type['account_type'] && chart_of_account.sub_type == accepted_account_type['account_detail_type']
      end

      accepted_chart_of_account_ids += chart_of_accounts.map(&:chart_of_account_id) unless chart_of_accounts.count.zero?
    end

    report.update!(accepted_chart_of_account_ids: accepted_chart_of_account_ids)
  rescue DocytServerClient::ApiError => e
    DocytLib.logger.debug(e.message)
  end
end
