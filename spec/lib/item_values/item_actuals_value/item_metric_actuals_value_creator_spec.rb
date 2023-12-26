# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue # rubocop:disable Metrics/ModuleLength
    RSpec.describe ItemMetricActualsValueCreator do
      before do
        allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(metrics_service_value_api_instance)
        allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
      end

      let(:metrics_service_category_value_response) { Struct.new(:value).new(30.0) }
      let(:metrics_service_value_api_instance) do
        instance_double(MetricsServiceClient::ValueApi, get_metric_value: metrics_service_category_value_response)
      end

      let(:metric_start_date) { Time.zone.today - 10.days }
      let(:business_metric_response) do
        instance_double(MetricsServiceClient::BusinessMetricResponse,
                        id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                        data_type: 'currency', start_date: metric_start_date, input_data_mode: 'Integration')
      end
      let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
      let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) do
        Report.create!(report_service: report_service, template_id: 'operators_operating_statement',
                       slug: 'operators_operating_statement', name: 'report', period_type: ReportData::PERIOD_DAILY)
      end
      let(:metric_item1) do
        report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                             type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms', 'code' => 'available_rooms' } })
      end
      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:last_year_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
      let(:mtd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT) }
      let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-03-01', end_date: '2020-03-31') }
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
            item_id: metric_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'metric_item1',
            value: 20.0
          }
        ]
      end
      let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
      let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

      describe '#call' do
        it 'creates item_value for TYPE_METRIC item and RANGE_CURRENT & YEAR_CURRENT column' do
          item_value = described_class.new(
            report_data: report_data,
            item: metric_item1,
            column: current_actual_column,
            standard_metrics: [],
            dependent_report_datas: {},
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
          expect(metrics_service_value_api_instance).to have_received(:get_metric_value).with(business_id, 'available_rooms', '2020-03-01'.to_date, '2020-03-31'.to_date).once
          expect(item_value.value).to eq(30.0)
          expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
        end

        it 'creates item_value for TYPE_METRIC item and RANGE_CURRENT & YEAR_PRIOR column' do
          item_value = described_class.new(
            report_data: report_data,
            item: metric_item1,
            column: last_year_actual_column,
            standard_metrics: [],
            dependent_report_datas: {},
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
          expect(metrics_service_value_api_instance).to have_received(:get_metric_value).with(business_id, 'available_rooms', '2019-03-01'.to_date, '2019-03-31'.to_date).once
          expect(item_value.value).to eq(30.0)
          expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
        end

        it 'creates item_value for TYPE_METRIC item and RANGE_MTD column' do
          item_value = described_class.new(
            report_data: report_data,
            item: metric_item1,
            column: mtd_actual_column,
            standard_metrics: [],
            dependent_report_datas: {},
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
          expect(item_value.value).to eq(30.0)
          expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
        end

        it 'creates item_value for TYPE_METRIC item and RANGE_YTD column' do
          item_value = described_class.new(
            report_data: report_data,
            item: metric_item1,
            column: ytd_actual_column,
            standard_metrics: [],
            dependent_report_datas: {},
            all_business_chart_of_accounts: [],
            accounting_classes: [],
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
          expect(item_value.value).to eq(30.0)
          expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
        end
      end
    end
  end
end
