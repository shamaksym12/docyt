# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue
    RSpec.describe ItemActualsValueCreator do
      subject(:item_value_creator) do
        described_class.new(
          report_data: report_data,
          item: current_item,
          column: current_column,
          standard_metrics: [],
          dependent_report_datas: [],
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        )
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
      let(:general_ledger_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
      let(:balance_sheet_item) do
        report.items.create!(name: 'parent_item1', order: 2, identifier: 'parent_item1',
                             type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE })
      end
      let(:total_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', totals: true) }
      let(:metric_item) do
        report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                             type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
      end
      let(:reference_item) do
        report.items.create!(name: 'Rooms Available to sell', order: 4, identifier: 'reference_item1',
                             type_config: { 'name' => Item::TYPE_REFERENCE, 'metric' => { 'name' => 'Available Rooms' } })
      end
      let(:stats_percentage_item) do
        report.items.create!(name: 'stats_percentage_item', order: 2, identifier: 'stats_percentage_item', type_config: { 'name' => Item::TYPE_STATS },
                             values_config: JSON.parse(File.read('./spec/data/values_config/stats_percentage_item.json')))
      end

      let(:ptd_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:ytd_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }
      let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
      let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

      describe '#creator_class' do
        context 'when current_item is reference type' do
          let(:current_item) { reference_item }
          let(:current_column) { ptd_column }

          it 'returns ItemReferenceActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemReferenceActualsValueCreator)
          end
        end

        context 'when current_item is stat type' do
          let(:current_item) { stats_percentage_item }
          let(:current_column) { ptd_column }

          it 'returns ItemStatActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemStatActualsValueCreator)
          end
        end

        context 'when current_item is totals type' do
          let(:current_item) { total_item }
          let(:current_column) { ptd_column }

          it 'returns ItemTotalActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemTotalActualsValueCreator)
          end
        end

        context 'when current_item is metric type' do
          let(:current_item) { metric_item }
          let(:current_column) { ptd_column }

          it 'returns ItemMetricActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemMetricActualsValueCreator)
          end
        end

        context 'when current_item is ptd type and item has general_ledger' do
          let(:current_item) { general_ledger_item }
          let(:current_column) { ptd_column }

          it 'returns ItemGeneralLedgerActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemGeneralLedgerActualsValueCreator)
          end
        end

        context 'when current_item is ptd type and item has balance_sheet' do
          let(:current_item) { balance_sheet_item }
          let(:current_column) { ptd_column }

          it 'returns ItemGeneralLedgerActualsValueCreator' do
            creator = item_value_creator.send(:creator_class)
            expect(creator).to eq(ItemGeneralLedgerActualsValueCreator)
          end
        end
      end
    end
  end
end
