# frozen_string_literal: true

require 'rails_helper'

module Quickbooks
  RSpec.describe GeneralLedgerAnalyzer do
    before do
      allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_service_api_instance)
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:report) { Report.create!(name: 'Test Report', report_service: report_service, template_id: 'test_template', slug: 'test_template') }
    let(:report_data) { create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }

    let(:account_value_link) { instance_double(DocytServerClient::AccountValueLink, qbo_id: 'qbo_id', link: 'qbo_id') }
    let(:report_service_api_instance) { instance_double(DocytServerClient::ReportServiceApi, get_account_value_links: [account_value_link]) }

    describe '#analyze' do
      subject(:analyze) { described_class.analyze(line_item_details_raw_data: line_item_details_raw_data) }

      let(:line_item_details_raw_data) { file_fixture('qbo_general_ledger_line_item_details.json').read }

      it 'creates general_ledger_line_item_details' do
        expect(analyze.length).to eq(12)
      end
    end
  end
end
