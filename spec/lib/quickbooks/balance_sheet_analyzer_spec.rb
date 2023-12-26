# frozen_string_literal: true

require 'rails_helper'

module Quickbooks
  RSpec.describe BalanceSheetAnalyzer do
    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:report) { Report.create!(name: 'Test Report', report_service: report_service, template_id: 'test_template', slug: 'test_template') }
    let(:report_data) { create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:balance_sheet_general_ledger) do
      ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date)
    end

    describe '#analyze' do
      subject(:analyze) { described_class.analyze(line_item_details_raw_data: line_item_details_raw_data) }

      context 'with normal ledger' do
        let(:line_item_details_raw_data) { file_fixture('balance_sheet_line_item_details_raw_data.json').read }

        it 'creates line_item_details for balance_sheet_general_ledger' do
          balance_sheet_general_ledger.update(line_item_details: analyze)
          expect(balance_sheet_general_ledger.line_item_details.count).to eq(11)
        end
      end

      context 'with specific general ledger' do
        let(:lodging_tax_chart_of_account_qbo_id) { '192' }
        let(:lodging_balance_chart_of_account_qbo_id) { '54' }
        let(:line_item_details_raw_data) { file_fixture('balance_sheet_line_item_details_raw_data1.json').read }

        it "creates line_item_details for specific chart_of_account '23015 LODGING TAX %'" do
          balance_sheet_general_ledger.update(line_item_details: analyze)
          line_item_detail = balance_sheet_general_ledger.line_item_details.find_by(chart_of_account_qbo_id: lodging_tax_chart_of_account_qbo_id)
          expect(line_item_detail).to be_present
        end

        it 'returns amount = 0.0 when does not exits amount value' do
          balance_sheet_general_ledger.update(line_item_details: analyze)
          line_item_detail = balance_sheet_general_ledger.line_item_details.find_by(chart_of_account_qbo_id: lodging_balance_chart_of_account_qbo_id)
          expect(line_item_detail.amount).to eq(0.0)
        end
      end
    end
  end
end
