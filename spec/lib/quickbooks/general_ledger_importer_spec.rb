# frozen_string_literal: true

require 'rails_helper'

module Quickbooks
  RSpec.describe GeneralLedgerImporter do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Quickbooks::BalanceSheetAnalyzer).to receive(:new).and_return(balance_sheet_ledger_analyzer)
      allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(common_ledger_analyzer)
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:report) { Report.create!(name: 'Test Report', report_service: report_service, template_id: 'test_template', slug: 'test_template') }
    let!(:report_data) { create(:report_data, report: report, start_date: '2022-03-01', end_date: '2022-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:business_response) do
      instance_double(DocytServerClient::Business, id: 105, bookkeeping_start_date: (Time.zone.today - 1.month))
    end
    let(:business_info) { OpenStruct.new(business: business_response) }
    let(:business_cloud_service_authorization) { OpenStruct.new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
    let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi, get_business: business_info, get_qbo_connection: business_quickbooks_connection_info)
    end

    let(:balance_sheet_ledger_analyzer) { instance_double(Quickbooks::BalanceSheetAnalyzer, analyze: []) }
    let(:common_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: []) }

    describe '#import' do
      subject(:import_general_ledger) do
        described_class.import(
          report_service: report_service,
          general_ledger_class: general_ledger_class,
          start_date: report_data.start_date,
          end_date: report_data.end_date,
          qbo_authorization: business_cloud_service_authorization
        )
      end

      before do
        qbo_general_ledger_body = file_fixture('qbo_general_ledger_line_item_details.json').read
        balance_sheet_response_body = file_fixture('balance_sheet_line_item_details_raw_data.json').read
        stub_request(:get, /.*intuit.com.*GeneralLedger*/).to_return(
          status: 200,
          body: qbo_general_ledger_body,
          headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' }
        )
        stub_request(:get, /.*intuit.com.*BalanceSheet*/).to_return(
          status: 200,
          body: balance_sheet_response_body,
          headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        )
      end

      context 'with BalanceSheetGeneralLedger' do
        let(:general_ledger_class) { Quickbooks::BalanceSheetGeneralLedger }

        it 'calls api to intuit to fetch BalanceSheetGeneralLedger' do
          import_general_ledger
          qbo_general_ledger = Quickbooks::BalanceSheetGeneralLedger.find_by(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date)
          WebMock.should(have_requested(:get, /.*intuit.com.*BalanceSheet*/).once)
          expect(qbo_general_ledger).to be_present
        end

        it 'calls BalanceSheetAnalyzer' do
          import_general_ledger
          expect(balance_sheet_ledger_analyzer).to have_received(:analyze)
        end
      end

      context 'with CommonGeneralLedger' do
        let(:general_ledger_class) { Quickbooks::CommonGeneralLedger }

        it 'calls api to intuit to fetch CommonGeneralLedger' do
          import_general_ledger
          qbo_general_ledger = Quickbooks::CommonGeneralLedger.find_by(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date)
          WebMock.should(have_requested(:get, /.*intuit.com.*GeneralLedger*/).once)
          expect(qbo_general_ledger).to be_present
        end

        it 'calls GeneralLedgerAnalyzer' do
          import_general_ledger
          expect(common_ledger_analyzer).to have_received(:analyze)
        end
      end
    end
  end
end
