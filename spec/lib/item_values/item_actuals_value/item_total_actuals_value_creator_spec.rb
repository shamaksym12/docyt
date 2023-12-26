# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue
    RSpec.describe ItemTotalActualsValueCreator do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'report') }
      let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
      let(:total_item) { report.items.create!(name: 'total_parent_item', order: 3, identifier: 'total_parent_item', totals: true, parent_id: parent_item.id.to_s) }
      let(:child_item1) do
        item = report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:child_total_item) do
        item = report.items.create!(name: 'child_total_item', order: 1, identifier: 'child_total_item', totals: true,
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: child_item1.id.to_s)
        item
      end
      let(:child_item2) do
        item = report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item.item_accounts.create!(chart_of_account_id: 1003)
        item
      end
      let(:child_item3) do
        item = report.items.create!(name: 'child_item3', order: 1, identifier: 'child_item3',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item
      end

      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item_values) do
        [
          {
            item_id: child_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            value: 20.0
          },
          {
            item_id: child_total_item.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_total_item',
            value: 20.0
          },
          {
            item_id: child_item2.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item2',
            value: 20.0
          },
          {
            item_id: child_item3.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item3',
            value: 20.0
          }
        ]
      end
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-03-01', end_date: '2020-03-31') }
      let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
      let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

      describe '#call' do
        it 'creates item_value for parent item(total) and RANGE_CURRENT column' do
          report_data.item_values = item_values
          item_value = described_class.new(
            report_data: report_data,
            item: total_item,
            column: current_actual_column,
            standard_metrics: [],
            dependent_report_datas: {},
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
          expect(item_value.value).to eq(60.0)
          expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
        end
      end
    end
  end
end
