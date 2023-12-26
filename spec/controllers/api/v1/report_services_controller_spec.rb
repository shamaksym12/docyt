# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ReportServicesController do
  before do
    balance_sheet_report
    report_service.update(default_budget_id: budget.id)
    allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4) }
  let(:balance_sheet_report) do
    BalanceSheetReport.create!(report_service: report_service,
                               template_id: BalanceSheetReport::BALANCE_SHEET_REPORT, slug: BalanceSheetReport::BALANCE_SHEET_REPORT, name: 'Balance Sheet')
  end

  describe 'GET #by_business_id' do
    subject(:by_business_id_response) do
      get :by_business_id, params: params
    end

    let(:params) do
      {
        business_id: business_id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_business_id_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_business_id_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT #update_default_budget' do
    subject(:update_default_budget_response) do
      put :update_default_budget, params: params
    end

    let(:params) do
      {
        report_service_id: report_service.service_id,
        default_budget_id: budget._id
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        update_default_budget_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        update_default_budget_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
