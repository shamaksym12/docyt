# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue # rubocop:disable Metrics/ModuleLength
    RSpec.describe ItemReferenceActualsValueCreator do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) do
        Report.create!(
          report_service: report_service,
          template_id: 'operators_operating_statement', slug: 'operators_operating_statement',
          name: 'report', dependent_template_ids: ['owners_operating_statement']
        )
      end
      let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
      let(:child_item1) do
        item = report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:child_item2) do
        item = report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    negative: true, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item.item_accounts.create!(chart_of_account_id: 1003)
        item
      end
      let(:child_item3) do
        item = report.items.create!(name: 'child_item3', order: 1, identifier: 'child_item3', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    negative: true, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item
      end
      let(:metric_item1) do
        report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                             type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
      end
      let(:reference_item) do
        report.items.create!(name: 'reference_item', order: 4, identifier: 'reference_item',
                             type_config: { 'name' => Item::TYPE_REFERENCE, 'reference' => 'owners_operating_statement/rooms_available' }, parent_id: parent_item.id.to_s)
      end
      let(:reference_item_with_column_range) do
        report.items.create!(name: 'reference_item', order: 4, identifier: 'reference_item',
                             type_config: { 'name' => Item::TYPE_REFERENCE, 'reference' => 'owners_operating_statement/rooms_available', 'src_column_range' => 'ytd' },
                             parent_id: parent_item.id.to_s)
      end

      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:current_perevious_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
      let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:item_values) do
        [
          {
            item_id: child_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            value: 20.0
          },
          {
            item_id: metric_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'metric_item1',
            value: 20.0
          }
        ]
      end
      let(:dependent_report_item_values) do
        [
          {
            item_id: dependent_report_metric_item1.id.to_s,
            column_id: dependent_report_current_actual_column.id.to_s,
            item_identifier: 'rooms_available',
            value: 50.0
          },
          {
            item_id: dependent_report_metric_item1.id.to_s,
            column_id: dependent_report_ytd_actual_column.id.to_s,
            item_identifier: 'rooms_available',
            value: 70.0
          }
        ]
      end
      let(:previous_dependent_report_item_values) do
        [
          {
            item_id: dependent_report_metric_item1.id.to_s,
            column_id: dependent_report_ytd_actual_column.id.to_s,
            item_identifier: 'rooms_available',
            value: 60.0
          }
        ]
      end
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }

      let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
      let(:dependent_report_current_actual_column) { dependent_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:dependent_report_ytd_actual_column) { dependent_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:dependent_report_metric_item1) do
        dependent_report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                                       type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
      end
      let(:dependent_report_data) do
        dependent_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: dependent_report_item_values)
      end
      let(:previous_dependent_report_data) do
        dependent_report.report_datas.create!(
          period_type: ReportData::PERIOD_MONTHLY,
          start_date: '2021-01-01', end_date: '2021-01-31',
          item_values: previous_dependent_report_item_values
        )
      end
      let(:dependent_report_datas) { { 'owners_operating_statement' => dependent_report_data } }
      let(:business_chart_of_account1) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1', acc_type: 'Expense')
      end
      let(:business_chart_of_account2) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '90', display_name: 'name2', acc_type: 'Expense')
      end
      let(:business_chart_of_account3) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '60', display_name: 'name3', acc_type: 'Expense')
      end
      let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
      let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'Account1') }
      let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'Account2') }
      let(:accounting_classes) { [accounting_class1, accounting_class2] }
      let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
      let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

      describe '#call' do
        subject(:create_item_value) do
          described_class.new(
            report_data: report_data,
            item: current_item,
            column: current_column,
            standard_metrics: [],
            dependent_report_datas: dependent_report_datas,
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
        end

        context 'when current_column is actual column' do
          let(:current_item) { reference_item }
          let(:current_column) { current_actual_column }

          it 'creates item_value for TYPE_REFERENCE item and RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: reference_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(50.0)
          end
        end

        context 'when current_column is ytd actual column' do
          let(:current_item) { reference_item }
          let(:current_column) { ytd_actual_column }

          it 'creates item_value for TYPE_REFERENCE item and RANGE_YTD column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: reference_item.id.to_s, column_id: ytd_actual_column.id.to_s)
            expect(item_value.value).to eq(70.0)
          end
        end

        context 'when reference item has src_column_range' do
          let(:current_item) { reference_item_with_column_range }
          let(:current_column) { current_actual_column }

          it 'creates item_value for TYPE_REFERENCE item with column_range and RANGE_YTD column' do
            ytd_actual_column
            create_item_value
            item_value = report_data.item_values.find_by(item_id: reference_item_with_column_range.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(70.0)
          end
        end

        context "when column year is previous_period and dependent report doesn't contain such column" do
          let(:current_item) { reference_item_with_column_range }
          let(:current_column) { current_perevious_actual_column }

          it 'creates item_value for TYPE_REFERENCE item with column_range and RANGE_YTD column' do
            ytd_actual_column
            previous_dependent_report_data
            create_item_value
            item_value = report_data.item_values.find_by(item_id: current_item.id.to_s, column_id: current_column.id.to_s)
            expect(item_value.value).to eq(60.0)
          end
        end
      end
    end
  end
end
