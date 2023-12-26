# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budget_item_values
#
#  id                   :string
#  month                :integer
#  value                :float, default: 0.0
#

require 'rails_helper'

RSpec.describe BudgetItemValueSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4) }
  let(:budget_item) { budget.draft_budget_items.create!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:budget_item_value) { budget_item.budget_item_values.create!(month: 1, value: 1.2) }

  it 'contains budget_item_value information in json' do
    json_string = described_class.new(budget_item_value).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['budget_item_value']['id']).not_to be_nil
    expect(result_hash['budget_item_value']['month']).to eq(1)
    expect(result_hash['budget_item_value']['value']).to eq(1.2)
  end
end
