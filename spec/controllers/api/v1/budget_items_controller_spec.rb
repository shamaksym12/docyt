# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::BudgetItemsController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(user) # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(BudgetItemFactory).to receive(:auto_fill_items).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    budget_item
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022) }
  let(:budget_id) { budget._id.to_s }
  let(:budget_item) { DraftBudgetItem.create!(budget_id: budget.id, chart_of_account_id: 1, accounting_class_id: 1, is_blank: false, budget_item_values: []) }
  let(:business_advisor_response) { Struct.new(:id, :business_id).new(1, 105) }
  let(:business_advisors) { Struct.new(:business_advisors).new([business_advisor_response]) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
  end
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    search_business_chart_of_accounts: business_chart_of_accounts_response)
  end

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: params
    end

    let(:params) do
      {
        budget_id: budget_id,
        page: 1,
        filter: {
          chart_of_account_display_name: 'test',
          account_type: 'profit_loss',
          accounting_class_id: 1,
          hide_blank: 'true'
        }
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        index_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      before do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
      end

      it 'returns 403 response when the user has no permission' do
        index_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #upsert' do
    subject(:upsert_response) do
      post :upsert, params: params
    end

    let(:params) do
      {
        budget_id: budget_id,
        id: budget_item.id,
        budget_item_values: [1, 1]
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        upsert_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        upsert_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #auto_fill' do
    subject(:auto_fill_response) do
      post :auto_fill, params: params
    end

    let(:params) do
      {
        budget_id: budget_id,
        business_id: 105, year: 2022,
        increase: 1,
        clear: true,
        months: [1, 2],
        budget_item_ids: [budget_item.id]
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        auto_fill_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        auto_fill_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
