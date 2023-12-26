# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MultiBusinessReportsController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_user_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(MultiBusinessReportFactory).to receive(:new).and_return(report_factory_instance)
    allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(secure_user) # rubocop:disable RSpec/AnyInstance
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
    custom_multi_business_report
  end

  let(:secure_user) { Struct.new(:id).new(111) }
  let(:multi_business_report_service) { Struct.new(:id, :consumer_id).new(111, 222) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_report_service) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:custom_multi_business_report) do
    MultiBusinessReport.create!(report_ids: [custom_report.id], multi_business_report_service_id: 111,
                                template_id: 'owners_operating_statement', name: 'name1')
  end
  let(:report_factory_instance) do
    instance_double(MultiBusinessReportFactory, multi_business_report: custom_multi_business_report, create: true, update_config: true, update_report: true, success?: true)
  end
  let(:failure_factory_instance) do
    instance_double(MultiBusinessReportFactory, multi_business_report: custom_multi_business_report, create: true,
                                                update_config: true, update_report: true, success?: false, errors: ['error'])
  end
  let(:business_advisor_response) { Struct.new(:id, :business_id).new(1, business_id) }
  let(:business_advisors) { Struct.new(:business_advisors).new([business_advisor_response]) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:businesses_response) { Struct.new(:businesses).new([business_response]) }
  let(:businesses_api_instance) do
    instance_double(DocytServerClient::BusinessesApi, get_by_ids: businesses_response)
  end

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: {}
    end

    it 'returns 200 response' do
      index_response
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        report_service_ids: [custom_report.id],
        template_id: 'owners_operating_statement',
        name: 'test report'
      }
    end

    it 'returns 201 response' do
      create_response
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 response' do
      allow(MultiBusinessReportFactory).to receive(:new).and_return(failure_factory_instance)
      create_response
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET #show' do
    subject(:show_response) do
      get :show, params: params
    end

    let(:params) do
      {
        id: custom_multi_business_report._id
      }
    end

    it 'returns 200 response' do
      show_response
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT #update' do
    subject(:update_response) do
      put :update, params: params
    end

    let(:params) do
      {
        id: custom_multi_business_report._id,
        report_service_ids: [custom_report.id],
        template_id: 'owners_operating_statement',
        name: 'test report'
      }
    end

    it 'returns 200 response' do
      update_response
      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 response' do
      allow(MultiBusinessReportFactory).to receive(:new).and_return(failure_factory_instance)
      update_response
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_response) do
      delete :destroy, params: params
    end

    let(:params) do
      {
        id: custom_multi_business_report._id
      }
    end

    it 'returns 200 response' do
      destroy_response
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #update_report' do
    subject(:update_report_response) do
      post :update_report, params: params
    end

    let(:params) do
      {
        id: custom_multi_business_report._id
      }
    end

    it 'returns 200 response' do
      update_report_response
      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 response' do
      allow(MultiBusinessReportFactory).to receive(:new).and_return(failure_factory_instance)
      update_report_response
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
