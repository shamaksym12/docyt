# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetItemValueFactory do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022) }
  let(:budget_item) { DraftBudgetItem.create!(budget_id: budget.id, chart_of_account_id: 1, accounting_class_id: 1, budget_item_values: []) }

  describe '#upsert_batch' do
    it 'creates a new budget item' do
      result = described_class.upsert_batch(
        budget_item: budget_item,
        budget_item_values: [{ month: 1, value: 10 }, { month: 2, value: 10 }, { month: 3, value: 10 }]
      )
      expect(result).to be_success
      expect(budget.draft_budget_items.length).to eq(1)
      expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(30)
      expect(budget.draft_budget_items[0].is_blank).to be_falsey
    end
  end
end
