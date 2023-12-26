# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AdvancedReportsController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ServicePermissionManager).to receive(:can_access_advanced_report).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(AdvancedReportFactory).to receive(:new).and_return(report_factory_instance)
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(user) # rubocop:disable RSpec/AnyInstance
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
    allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_service_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::AccessControlApi).to receive(:new).and_return(access_control_api)
    column_actual
    report_data
  end

  let(:user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report_services) { Struct.new(:report_services).new([report_service]) }
  let(:custom_report) { AdvancedReport.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:column_actual) { custom_report.columns.find_or_create_by!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:report_factory_instance) { instance_double(AdvancedReportFactory, report: custom_report, create: true, update: true, enqueue_report_update: true, success?: true) }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-02-01', end_date: '2021-02-28', period_type: ReportData::PERIOD_MONTHLY) }
  let(:report_service_api_instance) { instance_double(DocytServerClient::ReportServiceApi, accessible_by_user_id: report_services) }
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
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, get_by_ids: users_response) }
  let(:can_access_response) { Struct.new(:can_access).new(true) }
  let(:access_control_api) { instance_double(DocytServerClient::AccessControlApi, can_access: can_access_response) }

  describe 'POST #create' do
    subject(:create_response) do
      post :create, params: params
    end

    context 'with valid params' do
      let(:params) do
        {
          advanced_report: {
            report_service_id: 1,
            template_id: 'owners_operating_statement',
            name: 'test report'
          }
        }
      end

      it 'returns 201 response when the user has permission' do
        create_response
        expect(response).to have_http_status(:created)
      end

      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      before do
        allow(AdvancedReportFactory).to receive(:new).and_return(report_factory_instance)
      end

      let(:report_factory_instance) { instance_double(AdvancedReportFactory, report: custom_report, create: true, success?: false, errors: 'error') }
      let(:params) do
        {
          advanced_report: {
            report_service_id: 12,
            template_id: 'owners_operating_statement',
            name: 'error report'
          }
        }
      end

      it 'returns 422 response' do
        create_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
