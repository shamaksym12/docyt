# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ReportsController do
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
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    column_actual
    report_data
    daily_report_data
  end

  let(:user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report_services) { Struct.new(:report_services).new([report_service]) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:column_actual) { custom_report.columns.find_or_create_by!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:report_factory_instance) { instance_double(AdvancedReportFactory, report: custom_report, create: true, update: true, enqueue_report_update: true, success?: true) }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-02-01', end_date: '2021-02-28', period_type: ReportData::PERIOD_MONTHLY) }
  let(:daily_report_data) { create(:report_data, report: custom_report, start_date: '2021-02-22', end_date: '2021-02-22', period_type: ReportData::PERIOD_DAILY) }
  let(:report_service_api_instance) { instance_double(DocytServerClient::ReportServiceApi, accessible_by_user_id: report_services) }
  let(:business_advisor_response) { Struct.new(:id, :business_id).new(1, business_id) }
  let(:business_advisors) { Struct.new(:business_advisors).new([business_advisor_response]) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month),
                                                 display_name: 'My Business', name: 'My Business')
  end
  let(:businesses_response) { Struct.new(:businesses).new([business_response]) }
  let(:businesses_api_instance) do
    instance_double(DocytServerClient::BusinessesApi, get_by_ids: businesses_response)
  end
  let(:business_chart_of_account) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
  end
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, get_by_ids: users_response) }
  let(:can_access_response) { Struct.new(:can_access).new(true) }
  let(:access_control_api) { instance_double(DocytServerClient::AccessControlApi, can_access: can_access_response) }

  let(:template_id) { ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID }
  let(:pl_report) do
    ProfitAndLossReport.create!(report_service: report_service, template_id: template_id, slug: template_id, name: 'name2')
  end

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      { report_service_id: report_service.service_id }
    end

    context 'with permission' do
      it 'returns 200 response' do
        index_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns 200 response when has read permission' do
        allow_any_instance_of(ServicePermissionManager).to receive(:can_access_to_report_service).and_return(true) # rubocop:disable RSpec/AnyInstance
        index_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      let(:cannot_access_response) { Struct.new(:can_access).new(false) }
      let(:cannot_access_control_api) { instance_double(DocytServerClient::AccessControlApi, can_access: cannot_access_response) }

      it 'returns 403 response when the user has no permission' do
        allow(DocytServerClient::AccessControlApi).to receive(:new).and_return(cannot_access_control_api)
        index_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #show' do
    subject(:show_response) do
      get :show, params: params
    end

    let(:params) do
      {
        id: custom_report._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        show_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        show_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #by_template_id' do
    subject(:by_template_id_response) do
      get :by_template_id, params: params
    end

    let(:params) do
      {
        business_id: business_id,
        template_id: custom_report.template_id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_template_id_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_template_id_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #by_slug' do
    subject(:by_slug_response) do
      get :by_slug, params: params
    end

    let(:params) do
      {
        business_id: business_id,
        slug: custom_report.template_id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_slug_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_slug_response
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without permission of basic report' do
      let(:params) do
        {
          business_id: business_id,
          slug: pl_report.template_id
        }
      end

      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_slug_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT #update' do
    subject(:update_response) do
      put :update, params: params
    end

    let(:params) do
      {
        id: custom_report._id,
        report: {
          name: 'new report name',
          accepted_chart_of_account_ids: [1, 2, 3],
          accepted_accounting_class_ids: [1, 2, 3]
        }
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        update_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        update_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_response) do
      delete :destroy, params: params
    end

    let(:params) do
      {
        id: custom_report._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        destroy_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        destroy_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #update_report' do
    subject(:update_report_response) do
      post :update_report, params: params
    end

    let(:params) do
      {
        id: custom_report._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        update_report_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        update_report_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #available_businesses' do
    subject(:available_businesses_response) do
      get :available_businesses, params: params
    end

    let(:params) do
      {
        template_id: 'owners_operating_statement'
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        available_businesses_response
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #last_updated_date' do
    subject(:last_updated_date_response) do
      get :last_updated_date, params: params
    end

    let(:params) do
      {
        business_id: business_id,
        slug: custom_report.template_id,
        from: '2021-01-01',
        to: '2021-03-31'
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        last_updated_date_response
        expect(response).to have_http_status(:ok)
        parsed_body = response.parsed_body
        expect(parsed_body['last_updated_date']).to eq(report_data.updated_at.to_date.to_s)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        last_updated_date_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
