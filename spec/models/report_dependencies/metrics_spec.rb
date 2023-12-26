# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Metrics, type: :model do
  before do
    allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(metrics_service_value_api_instance)
  end

  let(:metrics_service_digest_response) { Struct.new(:digest).new(30.0) }
  let(:metrics_service_value_api_instance) { instance_double(MetricsServiceClient::ValueApi, get_digest: metrics_service_digest_response) }
  let(:metrics_service_digest_response2) { Struct.new(:digest).new(20.0) }
  let(:metrics_service_value_api_instance2) { instance_double(MetricsServiceClient::ValueApi, get_digest: metrics_service_digest_response2) }

  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:item) { report.items.create!(name: 'name2', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_METRIC }) }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      item
      report_data.recalc_digest!
      expect(described_class.new(report_data)).not_to have_changed
      allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(metrics_service_value_api_instance2)
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
