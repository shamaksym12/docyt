# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportsInReportServiceUpdater do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(general_ledger_importer)
    allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(general_ledger_analyzer)
    allow(Quickbooks::BalanceSheetAnalyzer).to receive(:new).and_return(balance_sheet_analyzer)
    allow(ReportFactory).to receive(:new).and_return(report_factory)
    allow(RefillReportService).to receive(:new).and_return(refill_report_service)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

  let(:owner_report) { create(:report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement') }
  let(:report) do
    create(:report, name: 'Test Report', report_service: report_service,
                    template_id: 'test_template', slug: 'test_template', dependent_template_ids: ['owners_operating_statement'])
  end
  let(:departmental_report) { create(:report, name: 'Department Report', report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT) }
  let(:revenue_accounting_report) do
    create(:report, name: 'Revenue Accounting Report', report_service: report_service, template_id: Report::REVENUE_ACCOUNTING_REPORT, slug: Report::REVENUE_ACCOUNTING_REPORT)
  end
  let(:revenue_report) { create(:report, name: 'Revenue Accounting Report', report_service: report_service, template_id: Report::REVENUE_REPORT, slug: Report::REVENUE_REPORT) }

  let(:qbo_token) { OpenStruct.new(id: 1, uid: SecureRandom.uuid, second_token: Faker::Lorem.characters(number: 32)) }
  let(:general_ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, import: true, fetch_qbo_token: qbo_token) }
  let(:general_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }
  let(:balance_sheet_analyzer) { instance_double(Quickbooks::BalanceSheetAnalyzer, analyze: true) }

  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: Time.zone.today)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
  end
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2, sub_class]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, get_business: business_info)
  end
  let(:business_response2) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: '2020-01-01')
  end
  let(:business_info2) { Struct.new(:business).new(business_response2) }
  let(:business_api_instance2) do
    instance_double(DocytServerClient::BusinessApi, get_business: business_info2)
  end

  let(:qbo_throttling_error) do
    response = double( # rubocop:disable RSpec/VerifiedDoubles
      parsed: {
        'Fault' => {
          'Error' => [{
            'code' => '3001',
            'Detail' => 'ERROR'
          }]
        }
      },
      status: 429
    ).as_null_object
    OAuth2::Error.new(response)
  end
  let(:qbo_internal_server_error) do
    response = double( # rubocop:disable RSpec/VerifiedDoubles
      parsed: {
        'Fault' => {
          'Error' => [{
            'code' => '3100',
            'Detail' => 'ERROR'
          }]
        }
      },
      status: 500
    ).as_null_object
    OAuth2::Error.new(response)
  end
  let(:qbo_authorization_error) do
    response = double( # rubocop:disable RSpec/VerifiedDoubles
      parsed: {
        'Fault' => {
          'Error' => [{
            'code' => '3200',
            'Detail' => 'ERROR'
          }]
        }
      },
      status: 500
    ).as_null_object
    OAuth2::Error.new(response)
  end

  let(:daily_report_data) { create(:report_data, report: owner_report, start_date: '2022-03-01', end_date: '2022-03-01', period_type: ReportData::PERIOD_DAILY) }

  let(:report_factory) { instance_double(ReportFactory, sync_report_infos: true) }
  let(:refill_report_service) { instance_double(RefillReportService, refill: true) }

  describe 'update_all_reports' do
    subject(:update_all_reports) { described_class.update_all_reports(report_service) }

    context 'when QBO is disconnected' do
      before do
        allow(general_ledger_importer).to receive(:fetch_qbo_token).and_return(nil)
      end

      it 'updates update_state and error_msg for all reports' do
        owner_report
        update_all_reports
        owner_report.reload
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Report::ERROR_MSG_QBO_NOT_CONNECTED)
      end
    end

    context 'when QBO is connected' do
      it 'generates CommonGeneralLedgers and BalanceSheetGeneralLedgers from bookkeeping_start_date' do
        count = (Time.zone.today.month * 2) + 1
        owner_report
        update_all_reports
        expect(general_ledger_importer).to have_received(:import).exactly(count).times
      end

      it 'does not generate ProfitAndLossGeneralLedger' do
        owner_report
        update_all_reports
        expect(Quickbooks::ProfitAndLossGeneralLedger.all.count).to eq(0)
      end

      it 'generates CommonGeneralLedgers, BalanceSheetGeneralLedgers when departmental_report exists' do
        count = (Time.zone.today.month * 2) + 1
        owner_report
        departmental_report
        update_all_reports
        expect(general_ledger_importer).to have_received(:import).exactly(count).times
      end

      it 'calls refill method of RefillReportService' do
        owner_report
        update_all_reports
        expect(refill_report_service).to have_received(:refill)
      end

      it 'calls sync_report_infos method of ReportFactory' do
        owner_report
        update_all_reports
        expect(report_factory).to have_received(:sync_report_infos)
      end
    end

    context 'when QBO returns throttling error' do
      before do
        allow(general_ledger_importer).to receive(:import).and_raise(qbo_throttling_error)
      end

      it 'updates update_state and error_msg for all reports in a service' do
        owner_report
        departmental_report
        update_all_reports
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Quickbooks::Error::THROTTLING_ERROR)
        expect(departmental_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(departmental_report.error_msg).to eq(Quickbooks::Error::THROTTLING_ERROR)
      end
    end

    context 'when QBO returns internal server error' do
      before do
        allow(general_ledger_importer).to receive(:import).and_raise(qbo_internal_server_error)
      end

      it 'updates update_state and error_msg for all reports in a service' do
        owner_report
        departmental_report
        update_all_reports
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Quickbooks::Error::INTERNAL_SERVER_ERROR_MSG)
        expect(departmental_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(departmental_report.error_msg).to eq(Quickbooks::Error::INTERNAL_SERVER_ERROR_MSG)
      end
    end

    context 'when QBO returns Authorization error' do
      before do
        allow(general_ledger_importer).to receive(:import).and_raise(qbo_authorization_error)
      end

      it 'updates update_state and error_msg for all reports in a service' do
        owner_report
        update_all_reports
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Quickbooks::Error::AUTHORIZATION_FAILED_ERROR)
      end
    end
  end

  describe '#update_report' do
    subject(:update_report) { described_class.update_report(report: owner_report) }

    context 'when QBO is disconnected' do
      before do
        allow(general_ledger_importer).to receive(:fetch_qbo_token).and_return(nil)
      end

      it 'updates update_state and error_msg for owner report' do
        update_report
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Report::ERROR_MSG_QBO_NOT_CONNECTED)
      end
    end

    context 'when QBO is connected' do
      it 'calls refill method of RefillReportService' do
        update_report
        expect(refill_report_service).to have_received(:refill)
      end

      it 'calls sync_report_infos method of ReportFactory' do
        update_report
        expect(report_factory).to have_received(:sync_report_infos)
      end
    end

    context 'when QBO returns throttling error' do
      before do
        allow(general_ledger_importer).to receive(:import).and_raise(qbo_throttling_error)
      end

      it 'updates update_state and error_msg for the corresponding report' do
        update_report
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Quickbooks::Error::THROTTLING_ERROR)
      end
    end

    context 'when QBO returns internal server error' do
      before do
        allow(general_ledger_importer).to receive(:import).and_raise(qbo_internal_server_error)
      end

      it 'updates update_state and error_msg for the corresponding report' do
        update_report
        expect(owner_report.update_state).to eq(Report::UPDATE_STATE_FAILED)
        expect(owner_report.error_msg).to eq(Quickbooks::Error::INTERNAL_SERVER_ERROR_MSG)
      end
    end
  end
end
