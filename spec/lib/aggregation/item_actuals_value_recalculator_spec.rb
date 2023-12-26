# frozen_string_literal: true

require 'rails_helper'

module Aggregation # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemActualsValueRecalculator do
    before do
      allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
      item_value1
      item_value2
      item_value3
      item_value4
      item_value5
      item_value6
      item_value7
      item_value_for_budget1
      item_value_for_budget2
      item_value_for_budget3
      item_value_for_budget4
    end

    let(:metric_start_date) { Time.zone.today - 10.days }
    let(:business_metric_response) do
      instance_double(MetricsServiceClient::BusinessMetricResponse,
                      id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                      data_type: 'integer', start_date: metric_start_date, input_data_mode: 'Integration')
    end
    let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
    let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }

    let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
    let(:users_response) { Struct.new(:users).new([user_response]) }
    let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
    let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:owners_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: 'owners_operating_statement', name: 'name1' }, current_user: user).report
    end
    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget3) { Budget.create!(report_service: report_service, name: 'name', year: 2020) }
    let(:report_data) do
      owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-04-30',
                                         budget_ids: [budget1.id, budget2.id, budget3.id])
    end
    let(:report_data1) do
      owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31',
                                         budget_ids: [budget1.id, budget2.id, budget3.id])
    end
    let(:report_data2) do
      owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30',
                                         budget_ids: [budget1.id, budget2.id, budget3.id])
    end
    let(:report_datas) { [report_data1, report_data2] }
    let(:item1) { owners_report.find_item_by_identifier(identifier: 'misc_revenue') }
    let(:item2) { owners_report.find_item_by_identifier(identifier: 'other_revenue') }
    let(:column) { owners_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:budget_actual_column) { owners_report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item1.identifier) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: item2.identifier) }
    let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item1.identifier) }
    let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: item2.identifier) }
    let(:item_value_for_budget1) do
      report_data1.item_values.create!(item_id: item1._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item1.identifier,
                                       budget_values: [{ budget_id: budget1.id, value: 10 }, { budget_id: budget2.id, value: 20 }, { budget_id: budget3.id, value: 30 }])
    end
    let(:item_value_for_budget2) do
      report_data1.item_values.create!(item_id: item2._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item2.identifier,
                                       budget_values: [{ budget_id: budget1.id, value: 20 }, { budget_id: budget2.id, value: 30 }, { budget_id: budget3.id, value: 40 }])
    end
    let(:item_value_for_budget3) do
      report_data2.item_values.create!(item_id: item1._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item1.identifier,
                                       budget_values: [{ budget_id: budget1.id, value: 30 }, { budget_id: budget2.id, value: 40 }, { budget_id: budget3.id, value: 50 }])
    end
    let(:item_value_for_budget4) do
      report_data2.item_values.create!(item_id: item2._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item2.identifier,
                                       budget_values: [{ budget_id: budget1.id, value: 40 }, { budget_id: budget2.id, value: 50 }, { budget_id: budget3.id, value: 60 }])
    end
    let(:item4) { owners_report.find_item_by_identifier(identifier: 'other_income') }

    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
    let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }
    let(:cash_flow_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: 'cash_flow', name: 'cash_flow_report' }, current_user: user).report
    end
    let(:report_data3) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
    let(:report_data4) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
    let(:report_data5) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
    let(:report_datas1) { [report_data3, report_data4, report_data5] }
    let(:total_report_data) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-06-30') }
    let(:item3) { cash_flow_report.find_item_by_identifier(identifier: 'cash_temporary_cash_investments_beginning_of_period') }
    let(:column1) { cash_flow_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value5) { report_data3.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 3.0, item_identifier: item3.identifier) }
    let(:item_value6) { report_data4.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 4.0, item_identifier: item3.identifier) }
    let(:item_value7) { report_data5.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 5.0, item_identifier: item3.identifier) }

    describe '#call' do
      it 'creates item_value for actual_column' do
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: column, item: item1)
        expect(report_data.item_values.find_by(item_id: item1._id.to_s, column_id: column.id.to_s).value).to eq(6)
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: column, item: item2)
        expect(report_data.item_values.find_by(item_id: item2._id.to_s, column_id: column.id.to_s).value).to eq(8)
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: column, item: item2)
        expect(report_data.item_values.find_by(item_id: item2._id.to_s, column_id: column.id.to_s).value).to eq(8)
      end

      it 'creates item_value for budget_actual_column' do
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: budget_actual_column, item: item1)
        expect(report_data.item_values.find_by(item_id: item1._id.to_s, column_id: budget_actual_column.id.to_s).budget_values[0][:value]).to eq(40)
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: budget_actual_column, item: item2)
        expect(report_data.item_values.find_by(item_id: item2._id.to_s, column_id: budget_actual_column.id.to_s).budget_values[0][:value]).to eq(60)
        described_class.call(report_datas: report_datas, report_data: report_data, dependent_report_datas: [], column: budget_actual_column, item: item4)
        expect(report_data.item_values.find_by(item_id: item4._id.to_s, column_id: budget_actual_column.id.to_s).budget_values[0][:value]).to eq(0.0)
      end

      it 'create item value of total report data for Balance Sheet Balance item' do
        described_class.call(report_datas: report_datas1, report_data: total_report_data, dependent_report_datas: [], column: column1, item: item3)
        expect(total_report_data.item_values.find_by(item_id: item3._id.to_s).value).to eq(3.0)
      end
    end
  end
end
