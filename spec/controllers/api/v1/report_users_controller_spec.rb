# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ReportUsersController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_id) { custom_report._id.to_s }
  let(:report_user) { custom_report.report_users.find_or_create_by!(user_id: 1) }
  let(:user_id) { 1 }

  describe 'POST #create' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        report_id: report_id,
        user_id: user_id
      }
    end

    context 'with permission' do
      it 'returns 201 response' do
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
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
        report_id: report_id,
        id: report_user._id.to_s
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
end
