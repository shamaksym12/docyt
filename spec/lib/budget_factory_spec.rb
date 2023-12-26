# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', parent_id: 101, mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', parent_id: 102, mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', parent_id: 1001, mapped_class_ids: [1, 2, 3])
  end
  let(:business_all_chart_of_account_info) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, search_business_chart_of_accounts: business_all_chart_of_account_info)
  end

  let(:user) { Struct.new(:id).new(1) }
  let(:params) { { year: 2022, name: 'Test Budget' } }

  describe '#create' do
    it 'creates a new budget' do # rubocop:disable RSpec/MultipleExpectations
      result = described_class.create(current_user: user, report_service: report_service, params: params)
      expect(result).to be_success
      expect(result.budget).not_to be_nil
      expect(result.budget.report_service.service_id).to eq(132)
      expect(result.budget.year).to eq(2022)
      expect(result.budget.updated_at).to be_present
    end

    it 'creates new budget items' do
      result = described_class.create(current_user: user, report_service: report_service, params: params)
      expect(result.budget.draft_budget_items).not_to be_nil
      expect(result.budget.draft_budget_items.count).to eq(6)
      expect(result.budget.actual_budget_items).not_to be_nil
      expect(result.budget.actual_budget_items.count).to eq(6)
    end
  end
end
