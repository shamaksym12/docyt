# frozen_string_literal: true

require 'rails_helper'

module AccountValue # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemAccountValuesQuery do
    let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
    let(:owner_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
    let(:report_data) { create(:report_data, report: owner_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:item1) do
      item = owner_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1')
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1)
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 2)
      item
    end
    let(:item2) do
      item = owner_report.items.find_or_create_by!(name: 'name2', order: 1, identifier: 'name2', type_config:
        {
          'name' => 'quickbooks_ledger',
          'general_ledger_options' => {
            'only_classes' => [1],
            'include_account_types' => []
          }
        })
      item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 3)
      item
    end
    let(:actual_column) { owner_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:percentage_column) { owner_report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_account_value1) do
      report_data.item_account_values.create!(item_id: item1._id, column_id: actual_column._id, chart_of_account_id: 1, accounting_class_id: 1, value: 1.0)
    end
    let(:item_account_value2) do
      report_data.item_account_values.create!(item_id: item1._id, column_id: actual_column._id, chart_of_account_id: 2, accounting_class_id: 1, value: 2.0)
    end
    let(:item_account_value3) do
      report_data.item_account_values.create!(item_id: item1._id, column_id: percentage_column._id, chart_of_account_id: 1, accounting_class_id: 1, value: 3.0)
    end
    let(:item_account_value4) do
      report_data.item_account_values.create!(item_id: item1._id, column_id: percentage_column._id, chart_of_account_id: 2, accounting_class_id: 1, value: 4.0)
    end
    let(:item_account_value5) do
      report_data.item_account_values.create!(item_id: item2._id, column_id: actual_column._id, chart_of_account_id: 3, accounting_class_id: 1, value: 5.0)
    end
    let(:item_account_value6) do
      report_data.item_account_values.create!(item_id: item2._id, column_id: percentage_column._id, chart_of_account_id: 3, accounting_class_id: 1, value: 6.0)
    end

    describe '#item_account_values' do
      before do
        item_account_value1
        item_account_value2
        item_account_value3
        item_account_value4
        item_account_value5
        item_account_value6
      end

      it 'returns item_account_values for one month' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-03-31',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(4)
      end

      it 'returns item_account_values for several months without total' do
        owner_report.update(total_column_visible: false)
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(2)
      end

      it 'returns item_account_values for several months with total' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(4)
      end

      it 'returns item_account_values for dervied mapping item' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name2'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(2)
      end

      it 'returns total item_account_values for balance sheet report' do
        report_data.update(start_date: '2021-04-01', end_date: '2021-04-30')
        item1.update(type_config: { Item::CALCULATION_TYPE_CONFIG => Item::BALANCE_SHEET_CALCULATION_TYPE })
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values
        expect(account_values.count).to eq(4)
      end

      it 'returns item_account_values for export excel' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values(only_actual_column: false)
        expect(account_values.count).to eq(4)
      end
    end

    describe '#item_account_values_for_multi_business_report' do
      before do
        item_account_value1
        item_account_value2
        item_account_value3
        item_account_value4
        item_account_value5
        item_account_value6
      end

      it 'returns total item_account_values' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values_for_multi_business_report
        expect(account_values.count).to eq(2)
      end

      it 'returns item_account_values for dervied mapping item' do
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name2'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values_for_multi_business_report
        expect(account_values.count).to eq(1)
      end

      it 'returns total item_account_values for balance sheet report' do
        owner_report.update(template_id: 'advanced_balance_sheet')
        report_data.update(start_date: '2021-04-01', end_date: '2021-04-30')
        item1.update(type_config: { Item::CALCULATION_TYPE_CONFIG => Item::BALANCE_SHEET_CALCULATION_TYPE })
        item_account_values_params =
          {
            from: '2021-03-01',
            to: '2021-04-30',
            item_identifier: 'name1'
          }

        account_values = described_class.new(report: owner_report, item_account_values_params: item_account_values_params).item_account_values_for_multi_business_report
        expect(account_values.count).to eq(2)
      end
    end
  end
end
