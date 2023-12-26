# frozen_string_literal: true

# == Mongoid Information
#
# Document name: MultiBusinessReportSerializer

require 'rails_helper'

RSpec.describe MultiBusinessReportSerializer do
  before do
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) do
    Report.create!(report_service: report_service, template_id: 'operators_operating_statement',
                   slug: 'operators_operating_statement', name: 'name1', updated_at: Time.zone.now)
  end
  let(:multi_business_report) do
    MultiBusinessReport.create!(multi_business_report_service_id: 111, template_id: 'operators_operating_statement',
                                name: 'name1', report_ids: [report.id])
  end
  let(:business_advisor_response) { OpenStruct.new(id: 1, business_id: business_id) }
  let(:business_advisors) { OpenStruct.new(business_advisors: [business_advisor_response]) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:businesses_response) { OpenStruct.new(businesses: [business_response]) }
  let(:businesses_api_instance) do
    instance_double(DocytServerClient::BusinessesApi, get_by_ids: businesses_response)
  end

  it 'contains multi_business_report in json' do # rubocop:disable RSpec/MultipleExpectations
    json_string = described_class.new(multi_business_report).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['multi_business_report']['id']).not_to be_nil
    expect(result_hash['multi_business_report']['multi_business_report_service_id']).to eq(111)
    expect(result_hash['multi_business_report']['last_updated_date']).not_to be_nil
    expect(result_hash['multi_business_report']['businesses']).not_to be_nil
    expect(result_hash['multi_business_report']['columns']).not_to be_nil
  end
end
