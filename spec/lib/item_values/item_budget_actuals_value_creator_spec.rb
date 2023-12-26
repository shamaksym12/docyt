# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemBudgetActualsValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:child_item1) do
      item = report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1',
                                  type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 11_882)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 597_202)
      item
    end
    let(:child_item2) do
      item = report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                  negative: true, parent_id: parent_item.id.to_s)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 11_882)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 597_202)
      item
    end
    let(:department_item) do
      report.items.create!(name: 'department_item', order: 1, identifier: 'revenue_4', parent_id: parent_item.id.to_s, type_config:
        {
          'name' => 'quickbooks_ledger',
          'general_ledger_options' => {
            'only_classes' => [accounting_class1.external_id],
            'include_account_types' => [
              'Expense',
              'Cost Of Goods Sold',
              'Other Expense'
            ]
          }
        })
    end
    let(:metric_item1) do
      report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                           type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
    end
    let(:metric_item2) do
      report.items.create!(name: 'Rooms Sold', order: 3, identifier: 'rooms_sold', type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Sold Rooms' } })
    end
    let(:reference_item1) do
      report.items.create!(name: 'Rooms Available to sell', order: 4, identifier: 'reference_item1',
                           type_config: { 'name' => Item::TYPE_REFERENCE, 'metric' => { 'name' => 'Available Rooms' } }, parent_id: parent_item.id.to_s)
    end
    let(:reference_item2) do
      report.items.create!(name: 'Rooms Sold', order: 4, identifier: 'reference_item2',
                           type_config: { 'name' => Item::TYPE_REFERENCE, 'metric' => { 'name' => 'Sold Rooms' } }, parent_id: parent_item.id.to_s)
    end
    let(:stats_plus_item) do
      report.items.create!(name: 'stats_plus_item', order: 2, identifier: 'stats_plus_item', type_config: { 'name' => Item::TYPE_STATS },
                           values_config: JSON.parse(File.read('./spec/data/values_config/stats_plus_item.json')), parent_id: parent_item.id.to_s)
    end
    let(:stats_minus_item) do
      report.items.create!(name: 'stats_minus_item', order: 2, identifier: 'stats_minus_item', type_config: { 'name' => Item::TYPE_STATS },
                           values_config: JSON.parse(File.read('./spec/data/values_config/stats_minus_item.json')), parent_id: parent_item.id.to_s)
    end
    let(:stats_sum_item) do
      report.items.create!(name: 'stats_sum_item', order: 2, identifier: 'stats_sum_item', type_config: { 'name' => Item::TYPE_STATS },
                           values_config: JSON.parse(File.read('./spec/data/values_config/stats_sum_item.json')), parent_id: parent_item.id.to_s)
    end
    let(:stats_percentage_item) do
      report.items.create!(name: 'stats_percentage_item', order: 2, identifier: 'stats_percentage_item', type_config: { 'name' => Item::TYPE_STATS },
                           values_config: JSON.parse(File.read('./spec/data/values_config/stats_percentage_item.json')), parent_id: parent_item.id.to_s)
    end

    let(:column1) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_column1) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }

    let(:admin_parent_item) { report.items.create!(name: 'admin_parent_item', order: 2, identifier: 'admin_parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
    let(:admin_total_item) { report.items.create!(name: 'total_admin_item', order: 2, identifier: 'total_admin_item', totals: true, parent_id: admin_parent_item.id.to_s) }
    let(:admin_child_item1) do
      report.items.create!(name: 'admin_child_item1', order: 1, identifier: 'admin_child_item1',
                           type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: admin_parent_item.id.to_s)
    end
    let(:admin_child_item2) do
      report.items.create!(name: 'admin_child_item2', order: 1, identifier: 'admin_child_item2',
                           type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: admin_parent_item.id.to_s)
    end
    let(:item_values) do
      [
        {
          item_id: admin_child_item1.id.to_s,
          column_id: column1.id.to_s,
          item_identifier: 'admin_child_item1',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: admin_child_item1.id.to_s,
          column_id: ytd_column1.id.to_s,
          item_identifier: 'admin_child_item1',
          value: 5.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        },
        {
          item_id: admin_child_item2.id.to_s,
          column_id: column1.id.to_s,
          item_identifier: 'admin_child_item2',
          value: 0.0,
          budget_values: [{ budget_id: budget1.id.to_s, value: 10.0 }, { budget_id: budget2.id.to_s, value: 10.0 }]
        }
      ]
    end
    let(:report_data_with_item_values) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: item_values)
    end

    let(:budget_item_values) do
      [
        { month: 1, value: 10.0 },
        { month: 2, value: 10.0 },
        { month: 3, value: 10.0 },
        { month: 4, value: 10.0 },
        { month: 5, value: 10.0 },
        { month: 6, value: 10.0 },
        { month: 7, value: 10.0 },
        { month: 8, value: 10.0 },
        { month: 9, value: 10.0 },
        { month: 10, value: 10.0 },
        { month: 11, value: 10.0 },
        { month: 12, value: 10.0 }
      ]
    end
    let(:standard_metric1) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
    let(:standard_metric2) { StandardMetric.create!(name: 'Rooms Sold', type: 'Sold Rooms', code: 'rooms_sold') }
    let(:standard_metrics) { [standard_metric1, standard_metric2] }
    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget3) { Budget.create!(report_service: report_service, name: 'name', year: 2020) }
    let(:actual_budget_items) do
      ActualBudgetItem.create!(budget_id: budget1.id, standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 11_882, accounting_class_id: accounting_class1.id, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 597_202, accounting_class_id: accounting_class1.id, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 11_882, accounting_class_id: accounting_class1.id, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 597_202, accounting_class_id: accounting_class1.id, budget_item_values: budget_item_values)
      ActualBudgetItem.create!(budget_id: budget3.id, chart_of_account_id: 597_202, accounting_class_id: accounting_class1.id, budget_item_values: budget_item_values)
    end
    let(:budgets) { [budget1, budget2, budget3] }
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }
    let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
    let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
    let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }

    let(:business_chart_of_accounts) do
      JSON.parse(
        file_fixture('business_chart_of_accounts.json').read,
        object_class: Struct.new(:id, :business_id, :chart_of_account_id, :qbo_id, :qbo_error, :display_name, :parent_id, :mapped_class_ids, :acc_type)
      )
    end

    describe '#call' do
      before do
        child_item1
        child_item2
        actual_budget_items
      end

      it 'creates item_value for RANGE_CURRENT column' do
        item_value = described_class.new(
          report_data: report_data,
          item: child_item1,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(20.0)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id).count).to eq(2)
      end

      it 'creates item_value for RANGE_CURRENT column and derived mapped item' do
        item_value = described_class.new(
          report_data: report_data,
          item: department_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [accounting_class1, accounting_class2, sub_class],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(report_data.item_account_values.where(item_id: department_item._id, column_id: column1._id).count).to eq(1)
      end

      it 'creates item_value with budget account values for RANGE_CURRENT column' do
        described_class.new(
          report_data: report_data,
          item: child_item1,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id).count).to eq(2)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id)[0].budget_values[0][:value]).to eq(10)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id)[1].budget_values[0][:value]).to eq(10)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id)[0].chart_of_account_id).to eq(11_882)
      end

      it 'creates item_value for YEAR_PRIOR column' do
        column1.update(year: Column::YEAR_PRIOR)
        item_value = described_class.new(
          report_data: report_data,
          item: child_item1,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        expect(item_value.budget_values.count).to eq(1)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: column1._id).count).to eq(2)
      end

      it 'creates item_value for metric item' do
        item_value = described_class.new(
          report_data: report_data,
          item: metric_item1,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
      end

      it 'creates item_value for reference item' do
        item_value = described_class.new(
          report_data: report_data,
          item: reference_item1,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(10.0)
        expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
      end

      it 'creates item_value for stats(plus) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_plus_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(40.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(minus) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_minus_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(0.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(sum) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_sum_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(0.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for stats(percentage) item' do
        item_value = described_class.new(
          report_data: report_data,
          item: stats_percentage_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(100.0)
        expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
      end

      it 'creates item_value(total) for parent item' do
        item_value = described_class.new(
          report_data: report_data_with_item_values,
          item: admin_total_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(20.0)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value for ytd column' do
        report_data.item_values.new(
          item_id: admin_child_item1.id.to_s, column_id: column1.id.to_s, value: 0.0,
          budget_values: []
        )
        item_value = described_class.new(
          report_data: report_data,
          item: child_item1,
          column: ytd_column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(item_value.budget_values.count).to eq(2)
        expect(item_value.budget_values[0][:value]).to eq(40.0)
        expect(report_data.item_account_values.where(item_id: child_item1._id, column_id: ytd_column1._id).count).to eq(2)
        expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
      end

      it 'creates item_value with item_account_value_name for derived mapped item' do
        described_class.new(
          report_data: report_data,
          item: department_item,
          column: column1,
          standard_metrics: standard_metrics,
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: [accounting_class1, accounting_class2, sub_class],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
        expect(report_data.item_account_values.where(item_id: department_item._id, column_id: column1._id)[0].name).to eq('class01 ▸ Job Expenses')
      end
    end
  end
end
