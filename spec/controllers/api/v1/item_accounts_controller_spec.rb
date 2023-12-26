# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ItemAccountsController do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: parent_item.id.to_s) }
  let(:item_account_value) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:report_id) { custom_report._id.to_s }
  let(:item_value_factory_instance) { instance_double(ItemAccountFactory, copy_mapping: true, load_default_mapping: true, success?: true) }
  let(:failure_factory_instance) do
    instance_double(ItemAccountFactory, copy_mapping: true, create_batch: true, destroy_batch: true, load_default_mapping: true, success?: false, errors: ['error'])
  end

  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id.to_s,
        item_id: child_item._id.to_s
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

  describe 'POST #create_batch' do
    subject(:create_batch_response) do
      post :create_batch, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id.to_s,
        item_id: child_item._id.to_s,
        maps: [
          { chart_of_account_id: 1, accounting_class_id: 1 }
        ]
      }
    end

    context 'with permission' do
      it 'returns 201 response' do
        create_batch_response
        expect(response).to have_http_status(:created)
      end

      it 'returns failure response when it fails to create' do
        allow(ItemAccountFactory).to receive(:new).and_return(failure_factory_instance)
        create_batch_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_batch_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy_batch' do
    subject(:destroy_batch_response) do
      delete :destroy_batch, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        item_id: child_item._id,
        ids: [item_account_value._id]
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        destroy_batch_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns failure response when it fails to create' do
        allow(ItemAccountFactory).to receive(:new).and_return(failure_factory_instance)
        destroy_batch_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        destroy_batch_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #copy_mapping' do
    subject(:copy_mapping_response) do
      post :copy_mapping, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        src_report_service_id: report_service.service_id,
        template_id: 'owners_operating_statement'
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        allow(ItemAccountFactory).to receive(:new).and_return(item_value_factory_instance)
        copy_mapping_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns failure response when it fails to create' do
        allow(ItemAccountFactory).to receive(:new).and_return(failure_factory_instance)
        copy_mapping_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        copy_mapping_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #load_default_mapping' do
    subject(:load_default_mapping_response) do
      post :load_default_mapping, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        allow(ItemAccountFactory).to receive(:new).and_return(item_value_factory_instance)
        load_default_mapping_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns failure response when it fails to create' do
        allow(ItemAccountFactory).to receive(:new).and_return(failure_factory_instance)
        load_default_mapping_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        load_default_mapping_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
