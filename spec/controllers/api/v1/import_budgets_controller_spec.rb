# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ImportBudgetsController, type: :controller do
  before do
    allow_any_instance_of(ApplicationController).to receive(:secure_user).and_return(secure_user) # rubocop:disable RSpec/AnyInstance
    stub_request(:get, /.*internal.*by_token*/).to_return(status: 200, body: '{"file": {"id": "77"}}', headers: { 'Content-Type' => 'application/json' })
  end

  let(:secure_user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }

  describe 'POST #create with budget' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        file_token: 'test',
        budget_id: budget.id.to_s
      }
    end

    context 'with success' do
      it 'returns 201 response' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
