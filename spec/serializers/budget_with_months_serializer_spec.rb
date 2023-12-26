# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budgets
#
#  id                   :string
#  report_service_id    :integer
#  name                 :string
#  year                 :integer
#  total_amount         :float
#  creator_id           :integer
#  created_at           :datetime
#

require 'rails_helper'

RSpec.describe BudgetWithMonthsSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4, status: Budget::STATE_PUBLISHED) }

  it 'contains budget information in json' do
    json_string = described_class.new(budget).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['budget_with_months']['id']).not_to be_nil
    expect(result_hash['budget_with_months']['report_service_id']).to eq(report_service.service_id)
    expect(result_hash['budget_with_months']['name']).to eq('name')
    expect(result_hash['budget_with_months']['status']).to eq(Budget::STATE_PUBLISHED)
  end

  context 'when month_total_amounts' do
    before do
      budget_item_value
      budget_item_value1
    end

    let(:budget_item) { budget.draft_budget_items.create!(chart_of_account_id: 1, accounting_class_id: 1) }
    let(:budget_item1) { budget.draft_budget_items.create!(chart_of_account_id: 2, accounting_class_id: 2) }
    let(:budget_item_value) { budget_item.budget_item_values.create!(month: 1, value: 120.0) }
    let(:budget_item_value1) { budget_item1.budget_item_values.create!(month: 1, value: 3.4) }

    it 'contains month_total_amounts information in json' do
      json_string = described_class.new(budget).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['budget_with_months']['month_total_amounts'][0]).to eq(123.4)
    end
  end
end
