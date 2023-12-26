# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetItemFactory do
  before do
    allow(AutoFillBudgetService).to receive(:new).and_return(auto_fill_budget_service_instance)
    allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(ledger_importer)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022) }
  let(:standard_metric) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
  let(:budget_item1) do
    DraftBudgetItem.create!(
      budget_id: budget.id,
      standard_metric_id: standard_metric.id.to_s,
      budget_item_values: [
        { month: 1, value: 10 },
        { month: 2, value: 10 },
        { month: 3, value: 10 },
        { month: 4, value: 10 },
        { month: 5, value: 10 },
        { month: 6, value: 10 },
        { month: 7, value: 10 },
        { month: 8, value: 10 },
        { month: 9, value: 10 },
        { month: 10, value: 10 },
        { month: 11, value: 10 },
        { month: 12, value: 10 }
      ]
    )
  end
  let(:budget_item2) do
    DraftBudgetItem.create!(
      budget_id: budget.id,
      chart_of_account_id: 1,
      accounting_class_id: 1,
      budget_item_values: [
        { month: 1, value: 20 },
        { month: 2, value: 20 },
        { month: 3, value: 20 },
        { month: 4, value: 20 },
        { month: 5, value: 20 },
        { month: 6, value: 20 },
        { month: 7, value: 20 },
        { month: 8, value: 20 },
        { month: 9, value: 20 },
        { month: 10, value: 20 },
        { month: 11, value: 20 },
        { month: 12, value: 20 }
      ]
    )
  end
  let(:actuals) do
    [
      { standard_metric_id: standard_metric.id.to_s, chart_of_account_id: nil, accounting_class_id: nil,
        budget_item_values: [
          { month: 1, value: 15 },
          { month: 2, value: 15 },
          { month: 3, value: 15 },
          { month: 4, value: 15 },
          { month: 5, value: 15 },
          { month: 6, value: 15 },
          { month: 7, value: 15 },
          { month: 8, value: 15 },
          { month: 9, value: 15 },
          { month: 10, value: 15 },
          { month: 11, value: 15 },
          { month: 12, value: 15 }
        ] },
      { chart_of_account_id: 1, accounting_class_id: 1, standard_metric_id: nil,
        budget_item_values: [
          { month: 1, value: -120 },
          { month: 2, value: -10 },
          { month: 3, value: 0.0 },
          { month: 4, value: 0.0 },
          { month: 5, value: 0.0 },
          { month: 6, value: 0.0 },
          { month: 7, value: 0.0 },
          { month: 8, value: 0.0 },
          { month: 9, value: 0.0 },
          { month: 10, value: 0.0 },
          { month: 11, value: 0.0 },
          { month: 12, value: 0.0 }
        ] }
    ]
  end
  let(:auto_fill_budget_service_instance) { instance_double(AutoFillBudgetService, perform: true) }
  let(:ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, fetch_qbo_token: true) }

  describe '#upsert_item' do
    context 'when standard_metric' do
      let(:params) do
        {
          id: budget_item1.id.to_s,
          budget_item_values: [
            { month: 1, value: 10 },
            { month: 2, value: 10 },
            { month: 3, value: 10 },
            { month: 4, value: 10 },
            { month: 5, value: 10 },
            { month: 6, value: 10 },
            { month: 7, value: 10 },
            { month: 8, value: 10 },
            { month: 9, value: 10 },
            { month: 10, value: 10 },
            { month: 11, value: 10 },
            { month: 12, value: 10 }
          ]
        }
      end

      it 'upsert a draft budget item' do
        budget_item1
        budget_item2
        result = described_class.upsert_item(current_budget: budget, budget_item_params: params)
        expect(result).to be_success
        expect(budget.draft_budget_items.length).to eq(2)
        expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(120)
      end
    end

    context 'when chart_of_account' do
      let(:params) do
        { id: budget_item2.id.to_s, budget_item_values: [
          { month: 1, value: 20 },
          { month: 2, value: 20 },
          { month: 3, value: 20 },
          { month: 4, value: 20 },
          { month: 5, value: 20 },
          { month: 6, value: 20 },
          { month: 7, value: 20 },
          { month: 8, value: 20 },
          { month: 9, value: 20 },
          { month: 10, value: 20 },
          { month: 11, value: 20 },
          { month: 12, value: 20 }
        ] }
      end

      it 'upsert a draft budget item' do
        budget_item1
        budget_item2
        result = described_class.upsert_item(current_budget: budget, budget_item_params: params)
        expect(result).to be_success
        expect(budget.draft_budget_items.length).to eq(2)
        expect(budget.draft_budget_items[1].budget_item_values.sum(:value)).to eq(240)
      end
    end
  end

  describe '#auto_fill_items' do
    context 'when clear' do
      let(:params) do
        {
          business_id: 1,
          year: 2022,
          increase: 1,
          clear: true,
          months: [*1..12],
          budget_item_ids: [budget_item1.id.to_s, budget_item2.id.to_s]
        }
      end

      it 'auto fill draft_budget_items' do
        budget_item1
        budget_item2
        result = described_class.auto_fill_items(current_budget: budget, params: params)
        expect(result).to be_success
        expect(budget.draft_budget_items.length).to eq(2)
        expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(120.0)
        expect(budget.draft_budget_items[1].budget_item_values.sum(:value)).to eq(240.0)
      end
    end

    context 'when auto fill' do
      let(:params) do
        {
          business_id: business_id,
          year: 2022,
          increase: 2,
          clear: false,
          months: [*1..10],
          budget_item_ids: [budget_item1.id.to_s, budget_item2.id.to_s]
        }
      end

      it 'auto fill draft_budget_items' do
        budget_item1
        budget_item2
        result = described_class.auto_fill_items(current_budget: budget, params: params)
        expect(result).to be_success
        expect(budget.draft_budget_items.length).to eq(2)
        expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(120.0)
        expect(budget.draft_budget_items[1].budget_item_values.sum(:value)).to eq(240.0)
      end
    end
  end
end
