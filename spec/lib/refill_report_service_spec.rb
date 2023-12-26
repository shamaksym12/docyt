# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefillReportService do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(Quickbooks::UnincludedLineItemDetailsFactory).to receive(:new).and_return(unincluded_line_item_details_factory)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'name1') }
  let(:revenue_report) { Report.create!(report_service: report_service, template_id: 'revenue_report', slug: 'revenue_report', name: 'Revenue Report') }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
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
  let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:report_dependency) { instance_double(ReportDependencies::Base, has_changed?: false) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:item_value_factory) { instance_double(ItemValueFactory, generate_batch: true) }
  let(:unincluded_line_item_details_factory) { instance_double(Quickbooks::UnincludedLineItemDetailsFactory, create_for_report: true) }

  describe '#refill_report' do
    subject(:refill_report) do
      refill_report_service = described_class.new(report: report, start_date: start_date, end_date: end_date, period_type: period_type)
      refill_report_service.refill
    end

    context 'with PERIOD_MONTHLY type' do
      let(:report_data1) do
        create(
          :report_data,
          report: report,
          start_date: '2023-01-01',
          end_date: '2023-01-31',
          period_type: ReportData::PERIOD_MONTHLY
        )
      end

      let(:report_data2) do
        create(
          :report_data,
          report: report,
          start_date: '2023-02-01',
          end_date: '2023-02-28',
          period_type: ReportData::PERIOD_MONTHLY
        )
      end

      let(:report_data3) do
        create(
          :report_data,
          report: report,
          start_date: '2023-03-01',
          end_date: '2023-03-31',
          period_type: ReportData::PERIOD_MONTHLY
        )
      end

      let(:report_data4) do
        create(
          :report_data,
          report: report,
          start_date: '2023-04-01',
          end_date: '2023-04-30',
          period_type: ReportData::PERIOD_MONTHLY
        )
      end

      let(:start_date) { Date.new(2023, 1, 1) }
      let(:end_date) { Date.new(2023, 4, 30) }
      let(:period_type) { ReportData::PERIOD_MONTHLY }

      it 'publishes events to refill report_datas' do
        expect do
          refill_report
        end.to change { DocytLib.async.event_queue.size }.by(4)
      end

      it 'does not publish events when report_datas all exist and dependencies has not changed' do
        # Prepare report_datas from January to current date.
        report_data1
        allow(ReportDependencies::Base).to receive(:new).and_return(report_dependency)
        expect do
          refill_report
        end.to change { DocytLib.async.event_queue.size }.by(3)
      end

      it 'publishes an event when no data is changable' do
        report_data1
        report_data2
        report_data3
        report_data4
        allow(ReportDependencies::Base).to receive(:new).and_return(report_dependency)
        expect do
          refill_report
        end.to change { DocytLib.async.event_queue.size }.by(1)
      end
    end

    context 'with PERIOD_DAILY type' do
      let(:start_date) { Time.zone.now.at_beginning_of_month }
      let(:end_date) { Time.zone.now.at_beginning_of_month }
      let(:period_type) { ReportData::PERIOD_DAILY }

      it 'publishes an event to refill report data' do
        expect do
          refill_report
        end.to change { DocytLib.async.event_queue.size }.by(1)
      end
    end
  end

  describe '#refill_report_data' do
    subject(:refill_report_data) do
      refill_report_service = described_class.new(report: report, start_date: start_date, end_date: end_date, period_type: period_type)
      refill_report_service.refill_report_data
    end

    before do
      allow(ItemValueFactory).to receive(:new).and_return(item_value_factory)
    end

    context 'with PERIOD_MONTHLY type' do
      let(:start_date) { Date.new(2023, 1, 1) }
      let(:end_date) { Date.new(2023, 1, 31) }
      let(:period_type) { ReportData::PERIOD_MONTHLY }

      it 'calls ItemValueFactory' do
        refill_report_data
        expect(item_value_factory).to have_received(:generate_batch).once
      end

      it 'calls UnincludedLineItemDetailsFactory' do
        report.update!(missing_transactions_calculation_disabled: false)
        refill_report_data
        expect(unincluded_line_item_details_factory).to have_received(:create_for_report).once
      end

      it 'publishes event that report data is generated' do
        expect do
          refill_report_data
        end.to change { DocytLib.async.event_queue.size }.by(1)
      end
    end

    context 'with PERIOD_DAILY type' do
      before do
        allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(general_ledger_importer)
        allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(general_ledger_analyzer)
        allow(Quickbooks::BalanceSheetAnalyzer).to receive(:new).and_return(balance_sheet_analyzer)
      end

      let(:qbo_token) { Struct.new(:id, :uid, :second_token).new(1, SecureRandom.uuid, Faker::Lorem.characters(number: 32)) }
      let(:general_ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, import: true, fetch_qbo_token: qbo_token) }
      let(:general_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }
      let(:balance_sheet_analyzer) { instance_double(Quickbooks::BalanceSheetAnalyzer, analyze: true) }
      let(:start_date) { Time.zone.now.at_beginning_of_month }
      let(:end_date) { Time.zone.now.at_beginning_of_month }
      let(:period_type) { ReportData::PERIOD_DAILY }

      it 'calls ItemValueFactory' do
        refill_report_data
        expect(item_value_factory).to have_received(:generate_batch).once
      end
    end

    context 'with error case' do
      before do
        allow(item_value_factory).to receive(:generate_batch).and_raise(StandardError)
      end

      let(:start_date) { Date.new(2023, 1, 1) }
      let(:end_date) { Date.new(2023, 1, 31) }
      let(:period_type) { ReportData::PERIOD_MONTHLY }

      it 'updates update_state and error_msg for the report' do
        refill_report_data
        expect(report.reload.update_state).to eq(Report::UPDATE_STATE_FAILED)
      end

      it 'logs the 500 error with Rollbar' do
        allow(item_value_factory).to receive(:generate_batch).and_raise(DocytServerClient::ApiError)
        expect { refill_report_data }.to raise_error(DocytServerClient::ApiError)
      end
    end
  end
end
