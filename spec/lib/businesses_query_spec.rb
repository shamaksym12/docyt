# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BusinessesQuery do
  before do
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
    allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_service_api_instance)
  end

  let(:user) { OpenStruct.new(id: 1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report_services) { OpenStruct.new(report_services: [report_service]) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
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
  let(:report_service_api_instance) { instance_double(DocytServerClient::ReportServiceApi, accessible_by_user_id: report_services) }

  describe '#available_businesses' do
    it 'get available businesses' do
      report
      businesses = described_class.new.available_businesses(user: user, template_id: 'owners_operating_statement')
      expect(businesses.size).to eq(1)
    end
  end

  describe '#by_report_ids' do
    it 'get businesses by report ids' do
      report
      businesses = described_class.new.by_report_ids(report_ids: [report.id], template_id: 'owners_operating_statement')
      expect(businesses.size).to eq(1)
    end
  end
end
