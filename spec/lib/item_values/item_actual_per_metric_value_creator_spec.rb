# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemActualPerMetricValueCreator do
    subject(:create_item_value) do
      described_class.new(
        report_data: report_data,
        item: child_item,
        column: current_column,
        standard_metrics: [],
        dependent_report_datas: [],
        all_business_chart_of_accounts: [],
        accounting_classes: [],
        caching_report_datas_service: caching_report_datas_service,
        caching_general_ledgers_service: caching_general_ledgers_service
      ).call
    end

    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true) }
    let(:rooms_available_item) do
      report.items.create!(name: 'rooms_available', order: 1, identifier: 'rooms_available', type_config: { 'name' => Item::TYPE_METRIC }, parent_id: parent_item.id.to_s)
    end
    let(:rooms_sold_item) do
      report.items.create!(name: 'rooms_sold', order: 1, identifier: 'rooms_sold', type_config: { 'name' => Item::TYPE_METRIC }, parent_id: parent_item.id.to_s)
    end
    let(:child_item) do
      report.items.create!(name: 'child_item', order: 2, identifier: 'child_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
    end
    let(:actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:par_column) { report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_available', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:por_column) { report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_sold', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_par_column) { report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_available', range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_por_column) { report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_sold', range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28',
                                  item_values: item_values, item_account_values: item_account_values)
    end
    let(:item_values) do
      [
        {
          item_id: rooms_available_item.id.to_s,
          column_id: actual_column.id.to_s,
          item_identifier: 'rooms_available',
          value: 10.0
        },
        {
          item_id: rooms_available_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          item_identifier: 'rooms_available',
          value: 20.0
        },
        {
          item_id: rooms_sold_item.id.to_s,
          column_id: actual_column.id.to_s,
          item_identifier: 'rooms_sold',
          value: 40.0
        },
        {
          item_id: rooms_sold_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          item_identifier: 'rooms_sold',
          value: 50.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 100.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 120.0
        }
      ]
    end
    let(:item_account_values) do
      [
        {
          item_id: child_item.id.to_s,
          column_id: actual_column.id.to_s,
          name: 'item_account5',
          chart_of_account_id: 3435,
          accounting_class_id: nil,
          value: 100.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: ytd_actual_column.id.to_s,
          name: 'item_account6',
          chart_of_account_id: 3436,
          accounting_class_id: nil,
          value: 120.0
        }
      ]
    end
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

    describe '#call' do
      context 'when column is PAR and RANGE_CURRENT' do
        let(:current_column) { par_column }

        it 'creates item_value' do
          item_value = create_item_value
          expect(item_value[:value]).to eq(10.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
          expect(report_data.item_account_values.find_by(item_id: child_item._id, column_id: par_column._id).value).to eq(10.0)
        end

        it 'creates item_value with 0.0' do
          item_values[0][:value] = 0.0
          item_value = create_item_value
          expect(item_value[:value]).to eq(0.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when column is POR and RANGE_CURRENT' do
        let(:current_column) { por_column }

        it 'creates item_value' do
          item_value = create_item_value
          expect(item_value[:value]).to eq(2.5)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
          expect(report_data.item_account_values.find_by(item_id: child_item._id, column_id: por_column._id).value).to eq(2.5)
        end

        it 'creates item_value with 0.0' do
          item_values[2][:value] = 0.0
          item_value = create_item_value
          expect(item_value[:value]).to eq(0.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when column is PAR and RANGE_YTD' do
        let(:current_column) { ytd_par_column }

        it 'creates item_value' do
          item_value = create_item_value
          expect(item_value[:value]).to eq(6.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
          expect(report_data.item_account_values.find_by(item_id: child_item._id, column_id: ytd_par_column._id).value).to eq(6.0)
        end

        it 'creates item_value with 0.0' do
          item_values[1][:value] = 0.0
          item_value = create_item_value
          expect(item_value[:value]).to eq(0.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end

      context 'when column is POR and RANGE_YTD' do
        let(:current_column) { ytd_por_column }

        it 'creates item_value' do
          item_value = create_item_value
          expect(item_value[:value]).to eq(2.4)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
          expect(report_data.item_account_values.find_by(item_id: child_item._id, column_id: ytd_por_column._id).value).to eq(2.4)
        end

        it 'creates item_value with 0.0' do
          item_values[3][:value] = 0.0
          item_value = create_item_value
          expect(item_value[:value]).to eq(0.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end
    end
  end
end
