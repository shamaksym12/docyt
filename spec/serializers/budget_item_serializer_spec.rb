# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budget_items
#
#  id                   :string
#  chart_of_account_id  :integer
#  accounting_class_id  :integer
#  standard_metric_id   :string
#

require 'rails_helper'

RSpec.describe BudgetItemSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4) }
  let(:budget_item) { budget.draft_budget_items.create!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:budget_item_value) { budget_item.budget_item_values.create!(month: 1, value: 1.2) }

  context 'when chart_of_account' do
    it 'contains chart_of_account information in json' do
      json_string = described_class.new(budget_item).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['budget_item']['id']).not_to be_nil
      expect(result_hash['budget_item']['chart_of_account_id']).to eq(1)
      expect(result_hash['budget_item']['accounting_class_id']).to eq(1)
      expect(result_hash['budget_item']['standard_metric_id']).to be_nil
    end
  end

  context 'when standard_metric' do
    let(:standard_metric) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Availabel Rooms', code: 'rooms_available') }
    let(:budget_item1) { budget.draft_budget_items.create!(standard_metric_id: standard_metric.id) }

    it 'contains standard_metric information in json' do
      json_string = described_class.new(budget_item1).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['budget_item']['id']).not_to be_nil
      expect(result_hash['budget_item']['chart_of_account_id']).to be_nil
      expect(result_hash['budget_item']['accounting_class_id']).to be_nil
      expect(result_hash['budget_item']['standard_metric_id']).not_to be_nil
    end
  end
end
