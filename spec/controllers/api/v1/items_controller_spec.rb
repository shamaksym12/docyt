# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ItemsController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: parent_item.id) }
  let(:multi_business_report) do
    MultiBusinessReport.create!(report_ids: [custom_report.id], multi_business_report_service_id: 111,
                                template_id: 'owners_operating_statement', name: 'name1')
  end

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id
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
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
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
        report_id: custom_report._id,
        id: child_item._id
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

  describe 'PUT #update' do
    subject(:update_response) do
      put :update, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        name: 'test item',
        id: child_item._id
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
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
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
        report_id: custom_report._id,
        name: 'test item',
        id: child_item._id
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

  describe 'GET #by_multi_business_report' do
    subject(:by_multi_business_report_response) do
      get :by_multi_business_report, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        multi_business_report_id: multi_business_report._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        allow_any_instance_of(described_class).to receive(:ensure_multi_business_report).and_return(true) # rubocop:disable RSpec/AnyInstance
        by_multi_business_report_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_multi_business_report).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_multi_business_report_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #by_identifier' do
    subject(:by_identifier_response) do
      get :by_identifier, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        item_identifier: parent_item.identifier
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
        by_identifier_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_identifier_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
