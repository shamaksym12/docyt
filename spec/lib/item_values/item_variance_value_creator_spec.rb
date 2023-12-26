# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemVarianceValueCreator do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item') }
    let(:child_item) do
      item = report.items.create!(name: 'child_item', order: 1, identifier: 'child_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                  values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
      item.item_accounts.create!(chart_of_account_id: 1001)
      item.item_accounts.create!(chart_of_account_id: 1002)
      item
    end
    let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:prior_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
    let(:current_variance_column) { report.columns.create!(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT) }
    let(:current_ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:prior_ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR) }
    let(:ytd_variance_column) { report.columns.create!(type: Column::TYPE_VARIANCE, range: Column::RANGE_YTD) }
    let(:pp_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
    let(:variance_column_with_pp) { report.columns.create!(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
    let(:report_data) do
      report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28',
                                  item_values: item_values, item_account_values: item_account_values)
    end
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
    let(:item_values) do
      [
        {
          item_id: child_item.id.to_s,
          column_id: current_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 30.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: prior_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 10.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: current_ytd_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 20.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: prior_ytd_actual_column.id.to_s,
          item_identifier: 'child_item',
          value: 10.0
        },
        {
          item_id: child_item.id.to_s,
          column_id: pp_column.id.to_s,
          item_identifier: 'child_item',
          value: 15.0
        }
      ]
    end
    let(:item_account_values) do
      [
        {
          item_id: child_item.id.to_s,
          column_id: current_actual_column.id.to_s,
          chart_of_account_id: 1001,
          name: '1',
          value: 20
        },
        {
          item_id: child_item.id.to_s,
          column_id: current_actual_column.id.to_s,
          chart_of_account_id: 1002,
          name: '2',
          value: 40
        },
        {
          item_id: child_item.id.to_s,
          column_id: prior_actual_column.id.to_s,
          chart_of_account_id: 1001,
          name: '1',
          value: 20
        }
      ]
    end
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

    describe '#call' do
      subject(:create_item_value) do
        described_class.new(
          report_data: report_data,
          item: child_item,
          column: variance_column,
          standard_metrics: [],
          dependent_report_datas: [],
          all_business_chart_of_accounts: business_chart_of_accounts,
          accounting_classes: accounting_classes,
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call
      end

      context 'when variance_column type is TYPE_VARIANCE for PTD' do
        let(:variance_column) { current_variance_column }

        it 'creates RANGE_CURRENT item_value' do
          item_value = create_item_value
          expect(item_value.value).to eq(20)
          expect(report_data.item_account_values.where(item_id: child_item._id, column_id: variance_column._id).count).to eq(2)
        end
      end

      context 'when variance_column type is TYPE_VARIANCE for YTD' do
        let(:variance_column) { ytd_variance_column }

        it 'creates RANGE_YTD item_value' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: ytd_variance_column.id.to_s)
          expect(item_value.value).to eq(10)
        end
      end

      context 'when variance_column type is TYPE_VARIANCE with PP column' do
        let(:variance_column) { variance_column_with_pp }

        it 'creates RANGE_CURRENT item_value' do
          create_item_value
          item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: variance_column_with_pp.id.to_s)
          expect(item_value.value).to eq(15)
        end
      end
    end
  end
end
