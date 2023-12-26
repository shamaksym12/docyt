# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiBusinessReportFactory do
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
  let(:multi_business_service) { OpenStruct.new(id: 101, consumer_id: user.id) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_service) }

  describe '#create' do
    context 'when owners_operating_statement' do
      let(:report_params) do
        {
          report_service_ids: [132],
          template_id: 'owners_operating_statement',
          name: 'name'
        }
      end

      it 'creates a new multi_business_report' do
        report
        result = described_class.create(current_user: user, params: report_params)
        expect(result).to be_success
        expect(result.multi_business_report).not_to be_nil
        expect(result.multi_business_report.columns.count).to eq(2)
      end
    end

    context 'when store_managers_report' do
      let(:report_params) do
        {
          report_service_ids: [132],
          template_id: 'store_managers_report',
          name: 'name'
        }
      end

      it 'creates a new multi_business_report' do
        report
        result = described_class.create(current_user: user, params: report_params)
        expect(result).to be_success
        expect(result.multi_business_report).not_to be_nil
        expect(result.multi_business_report.columns.count).to eq(4)
      end
    end

    context 'when advanced_balance_sheet' do
      let(:report_params) do
        {
          report_service_ids: [132],
          template_id: 'advanced_balance_sheet',
          name: 'name'
        }
      end

      it 'creates a new multi_business_report' do
        report
        result = described_class.create(current_user: user, params: report_params)
        expect(result).to be_success
        expect(result.multi_business_report).not_to be_nil
        expect(result.multi_business_report.columns.count).to eq(1)
      end
    end
  end

  describe '#update_config' do
    let(:report_params) do
      {
        report_service_ids: [132],
        template_id: 'owners_operating_statement',
        name: 'name'
      }
    end

    it 'updates multi_business_report' do
      result = described_class.update_config(multi_business_report: multi_business_report, params: report_params)
      expect(result).to be_success
    end
  end

  describe '#update_report' do
    it 'updates a new multi_business_report' do
      result = described_class.update_report(multi_business_report: multi_business_report)
      expect(result).to be_success
    end
  end
end
