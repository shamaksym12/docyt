# frozen_string_literal: true

module Quickbooks
  class GeneralLedgerImporter
    include DocytLib::Helpers::PerformanceHelpers
    include DocytLib::Utils::DocytInteractor
    attr_accessor :general_ledger

    GENERAL_LEDGER_URL = 'reports/GeneralLedger'
    BALANCE_SHEET_URL = 'reports/BalanceSheet'
    GENERAL_LEDGER_COLUMNS_ACC = 'tx_date,txn_type,doc_num,memo,vend_name,split_acc,subt_nat_amount,subt_nat_home_amount,subt_nat_amount_nt,subt_nat_amount_home_nt,account_name,klass_name' # rubocop:disable Layout/LineLength
    GENERAL_LEDGER_ACCOUNT_TYPES = 'Expense,CostOfGoodsSold,Income,OtherExpense,OtherIncome,Bank,AccountsReceivable,OtherCurrentAsset,FixedAsset,OtherAsset,AccountsPayable,CreditCard,OtherCurrentLiability,LongTermLiability,Equity' # rubocop:disable Layout/LineLength
    MINOR_VERSION = 57

    class << self
      delegate :fetch_qbo_token, to: :new
    end

    def import(report_service:, general_ledger_class:, start_date:, end_date:, qbo_authorization:) # rubocop:disable Metrics/MethodLength
      qbo_api_instance = qbo_access_token(qbo_authorization.second_token)
      old_general_ledger = general_ledger_class.where(report_service: report_service, start_date: start_date, end_date: end_date).first
      new_general_ledger = general_ledger_class.new(report_service: report_service, start_date: start_date, end_date: end_date)
      line_item_details_raw_data = fetch_qbo_general_ledger(
        qbo_company_id: qbo_authorization.uid,
        qbo_api_instance: qbo_api_instance,
        general_ledger: new_general_ledger
      )
      new_general_ledger.line_item_details = analyze_qbo_general_ledger(general_ledger: new_general_ledger, line_item_details_raw_data: line_item_details_raw_data)
      new_general_ledger.digest = new_general_ledger.calculate_digest
      has_changed = old_general_ledger&.digest != new_general_ledger.digest

      if has_changed
        general_ledger_class.where(report_service: report_service, start_date: start_date, end_date: end_date).destroy_all
        new_general_ledger.save!
        @general_ledger = new_general_ledger
      else
        new_general_ledger.destroy
        @general_ledger = old_general_ledger
      end
    end
    apm_method :import

    def fetch_qbo_token(report_service)
      business_api_instance = DocytServerClient::BusinessApi.new
      response = business_api_instance.get_qbo_connection(report_service.business_id)
      response.cloud_service_authorization
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
      nil
    end

    private

    def qbo_access_token(access_token)
      qbo_client = OAuth2::Client.new(
        DocytLib.config.quickbooks.client_id, DocytLib.config.quickbooks.client_secret,
        {
          site: 'https://appcenter.intuit.com',
          authorize_url: '/connect/oauth2',
          token_url: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
          redirect_uri: DocytLib.config.quickbooks.redirect_uri
        }
      )
      OAuth2::AccessToken.new(qbo_client, access_token)
    end

    def fetch_qbo_general_ledger(qbo_company_id:, qbo_api_instance:, general_ledger:)
      url = generate_url(qbo_company_id: qbo_company_id, general_ledger: general_ledger)
      DocytLib.logger.info("QBO request: GET #{url}")
      response = qbo_api_instance.get(url, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
      response.body
    end

    def analyze_qbo_general_ledger(general_ledger:, line_item_details_raw_data:)
      analyzer_class = if general_ledger.is_a?(Quickbooks::BalanceSheetGeneralLedger)
                         BalanceSheetAnalyzer
                       else
                         GeneralLedgerAnalyzer
                       end
      analyzer_class.analyze(line_item_details_raw_data: line_item_details_raw_data)
    end

    def generate_url(qbo_company_id:, general_ledger:) # rubocop:disable Metrics/MethodLength
      start_date = general_ledger.start_date
      end_date = general_ledger.end_date
      search_query = "accounting_method=Accrual&minorversion=#{MINOR_VERSION}"

      if general_ledger.is_a?(Quickbooks::BalanceSheetGeneralLedger)
        url = "#{DocytLib.config.quickbooks.api_base_uri}/#{qbo_company_id}/#{BALANCE_SHEET_URL}"
        url += "?start_date=#{start_date}&end_date=#{end_date}&#{search_query}"
      else
        search_query += "&columns=#{GENERAL_LEDGER_COLUMNS_ACC}"
        url = "#{DocytLib.config.quickbooks.api_base_uri}/#{qbo_company_id}/#{GENERAL_LEDGER_URL}"
        url += "?start_date=#{start_date}&end_date=#{end_date}&#{search_query}&account_type=#{GENERAL_LEDGER_ACCOUNT_TYPES}"
      end
      url
    end
  end
end
