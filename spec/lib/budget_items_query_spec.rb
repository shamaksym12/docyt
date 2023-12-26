# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetItemsQuery do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount, id: 1, business_id: 105, chart_of_account_id: 1001)
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount, id: 2, business_id: 105, chart_of_account_id: 1002)
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount, id: 3, business_id: 105, chart_of_account_id: 1003)
  end
  let(:business_chart_of_accounts) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi, search_business_chart_of_accounts: business_chart_of_accounts)
  end

  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022) }
  let(:budget_id) { budget._id.to_s }
  let(:budget_item) { DraftBudgetItem.create!(budget_id: budget_id, chart_of_account_id: 1001, accounting_class_id: 1, is_blank: false, budget_item_values: []) }
  let(:params) { { page: 1, per: 50, filter: { account_type: 'profit_loss', chart_of_account_display_name: 'Test', accounting_class_id: 1, hide_blank: 'true' } } }
  let(:params_not_paginated) { { filter: { account_type: 'profit_loss', chart_of_account_display_name: 'Test', accounting_class_id: 1, hide_blank: 'true' } } }

  describe '#all_budget_items' do
    it 'get all budget items' do
      budget_item
      result = described_class.new(current_budget: budget, params: params_not_paginated).all_budget_items
      expect(result.count).to eq(1)
      expect(result[0].is_blank).to be_falsey
    end
  end

  describe '#budget_items' do
    it 'get filtered and ordered budget items' do
      budget_item
      result = described_class.new(current_budget: budget, params: params).budget_items
      expect(result.count).to eq(1)
      expect(result[0].is_blank).to be_falsey
    end
  end

  describe '#month_total_amounts' do
    it 'get total amounts per month' do
      budget_item
      total_amount_per_month = described_class.new(current_budget: budget, params: params).month_total_amounts
      expect(total_amount_per_month.length).to eq(12)
      expect(total_amount_per_month.sum).to eq(0)
    end
  end
end
