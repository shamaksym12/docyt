# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MultiBusinessReportDatasController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(secure_user) # rubocop:disable RSpec/AnyInstance
  end

  let(:secure_user) { OpenStruct.new(id: 111) }
  let(:multi_business_report_service) { OpenStruct.new(id: 111, consumer_id: 222) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_report_service) }

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:custom_multi_business_report) do
    MultiBusinessReport.create!(report_ids: [custom_report.id], multi_business_report_service_id: 111,
                                template_id: 'owners_operating_statement', name: 'name1')
  end

  describe 'GET #by_range' do
    subject(:by_range_response) do
      get :by_range, params: params
    end

    let(:params) do
      {
        multi_business_report_id: custom_multi_business_report._id,
        from: '2021-01-01',
        to: '2021-03-31'
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_range_response
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #update_daily_report_datas' do
    subject(:update_daily_report_datas_response) do
      put :update_daily_report_datas, params: params
    end

    let(:params) do
      {
        multi_business_report_id: custom_multi_business_report._id,
        current: '2021-03-31',
        is_daily: true
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        update_daily_report_datas_response
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
