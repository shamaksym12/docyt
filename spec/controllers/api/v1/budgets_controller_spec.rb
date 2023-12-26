# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::BudgetsController do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(user) # rubocop:disable RSpec/AnyInstance
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, get_by_ids: users_response) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, parent_id: 101, mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, parent_id: 102, mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, parent_id: 1001, mapped_class_ids: [1, 2, 3])
  end
  let(:business_all_chart_of_account_info) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, search_business_chart_of_accounts: business_all_chart_of_account_info)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4) }

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      {
        report_service_id: report_service.service_id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        index_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        index_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #create' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        report_service_id: report_service.service_id,
        year: 2022,
        name: 'test budget'
      }
    end

    context 'with permission' do
      it 'returns 201 response when the user has permission' do
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
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
        id: budget._id.to_s
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
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        show_response
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
        id: budget._id.to_s,
        year: 2021,
        name: 'test budget name'
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

  describe 'DELETE #delete' do
    subject(:delete_response) do
      delete :destroy, params: params
    end

    let(:params) do
      {
        id: budget._id.to_s
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        delete_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        delete_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #by_ids' do
    subject(:by_ids_response) do
      get :by_ids, params: params
    end

    let(:params) do
      {
        id: budget._id.to_s,
        report_service_id: report_service.service_id,
        budget_ids: [budget._id.to_s]
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_ids_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_ids_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT #publish' do
    subject(:publish_response) do
      put :publish, params: params
    end

    let(:params) do
      {
        id: budget._id.to_s
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        publish_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        publish_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT #discard' do
    subject(:discard_response) do
      put :discard, params: params
    end

    let(:params) do
      {
        id: budget._id.to_s
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        discard_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        discard_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
