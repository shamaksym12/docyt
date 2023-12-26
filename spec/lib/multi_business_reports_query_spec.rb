# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiBusinessReportsQuery do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(ledger_importer)
    allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(ledger_analyzer)
    allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
  end

  let(:user) { OpenStruct.new(id: 1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:multi_business_report) do
    MultiBusinessReport.create!(report_ids: [report.id], multi_business_report_service_id: 111,
                                template_id: 'owners_operating_statement', name: 'name1')
  end
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:business_info) { OpenStruct.new(business: business_response) }
  let(:qbo_token) { OpenStruct.new(id: 1, uid: SecureRandom.uuid, second_token: Faker::Lorem.characters(number: 32)) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, get_business: business_info)
  end
  let(:ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, import: true, fetch_qbo_token: qbo_token) }
  let(:ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }
  let(:multi_business_service) { OpenStruct.new(id: 111, consumer_id: user.id) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_service) }

  describe '#multi_business_reports' do
    it 'returns multi_business_reports' do
      multi_business_report
      multi_business_reports = described_class.new.multi_business_reports(current_user: user)
      expect(multi_business_reports.count).to eq(1)
    end
  end
end
