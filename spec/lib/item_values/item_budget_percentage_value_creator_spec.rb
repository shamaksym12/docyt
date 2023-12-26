# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemBudgetPercentageValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:child_item1) do
      report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
    end
    let(:child_item2) do
      report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
    end
    let(:percentage_item) do
      item = report.items.create!(name: 'percentage_item', order: 2, identifier: 'percentage_item', parent_id: parent_item.id.to_s,
                                  values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
      item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1002)
      item
    end
    let(:source_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_source_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end
    let(:item_values) do
      [
        {
          item_id: child_item1.id.to_s,
          column_id: dependent_report_column1.id.to_s,
          item_identifier: 'child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: child_item2.id.to_s,
          column_id: source_column.id.to_s,
          item_identifier: 'child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: child_item1.id.to_s,
          column_id: dependent_report_column2.id.to_s,
          item_identifier: 'child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 20.0 }, { budget_id: budget2.id.to_s, value: 20.0 }]
        },
        {
          item_id: child_item2.id.to_s,
          column_id: ytd_source_column.id.to_s,
          item_identifier: 'child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end
    let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'dependent_report', slug: 'dependent_report', name: 'report') }
    let(:dependent_report_column1) { dependent_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:dependent_report_column2) { dependent_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:dependent_report_data) do
      dependent_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end
    let(:dependent_report_datas) { { 'owners_operating_statement' => dependent_report_data } }

    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }
    let(:budgets) { [budget1, budget2] }

    let(:budget_item_values) { [{ month: 2, value: 5.0 }] }

    let(:actual_budget_items) do
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1001, accounting_class_id: 1, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 1002, accounting_class_id: 2, budget_item_values: budget_item_values)
    end

    describe '#call' do
      before do
        actual_budget_items
      end

      it 'creates item_value of RANGE_CURRENT for BUDGET_PERCENTAGE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: percentage_item,
          column: percentage_column,
          standard_metrics: [],
          dependent_report_datas: dependent_report_datas,
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(100.0)
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: percentage_column._id).count).to eq(2)
      end

      it 'creates item_value of RANGE_CURRENT for BUDGET_PERCENTAGE column with budget account values' do
        described_class.new(
          report_data: report_data,
          item: percentage_item,
          column: percentage_column,
          standard_metrics: [],
          dependent_report_datas: dependent_report_datas,
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: percentage_column._id).count).to eq(2)
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: percentage_column._id).first.chart_of_account_id).to eq(1001)
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: percentage_column._id).first.budget_values[0][:value]).to eq(50.0)
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: percentage_column._id)[1].budget_values[0][:value]).to eq(50.0)
      end

      it 'creates item_value of RANGE_YTD for BUDGET_PERCENTAGE column' do
        item_value = described_class.new(
          report_data: report_data,
          item: percentage_item,
          column: ytd_percentage_column,
          standard_metrics: [],
          dependent_report_datas: dependent_report_datas,
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(50.0)
        expect(report_data.item_account_values.where(item_id: percentage_item._id, column_id: ytd_percentage_column._id).count).to eq(2)
      end
    end
  end
end
