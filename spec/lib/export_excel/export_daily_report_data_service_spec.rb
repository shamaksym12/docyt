# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportDailyReportDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
      allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
      item_value1
      item_value2
      item_value3
      item_value4
      item5
      item_account1
    end

    let(:metric_start_date) { Time.zone.today - 10.days }
    let(:business_metric_response) do
      instance_double(MetricsServiceClient::BusinessMetricResponse,
                      id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                      data_type: 'integer', start_date: metric_start_date, input_data_mode: 'Integration')
    end
    let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
    let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }

    let(:user) { Struct.new(:id).new(1) }
    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: 'revenue_report', name: 'name1' }, current_user: user).report
    end
    let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
    let(:users_response) { Struct.new(:users).new([user_response]) }
    let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
    let(:report_data1) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-01', period_type: ReportData::PERIOD_DAILY) }
    let(:last_reconciled_month_data) { Struct.new(:year, :month, :status).new(2021, 1, 'reconciled') }
    let(:business_response) do
      instance_double(DocytServerClient::BusinessDetail, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month),
                                                         display_name: 'My Business', name: 'My Business', last_reconciled_month_data: last_reconciled_month_data)
    end
    let(:business_info) { Struct.new(:business).new(business_response) }
    let(:business_chart_of_account1) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
    end
    let(:business_chart_of_account2) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
    end
    let(:business_chart_of_account3) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
    end
    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi, get_business: business_info,
                                                      get_business_chart_of_accounts: business_chart_of_accounts_response)
    end
    let(:sheet_row) { Struct.new(:outline_level, :hidden).new(0, false) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view) }
    let(:item1) { custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item1') }
    let(:item2) { custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item2') }
    let(:item3) { custom_report.items.find_or_create_by!(name: 'name3', order: 3, identifier: 'parent_item3', totals: true) }
    let(:item4) { custom_report.items.find_or_create_by!(name: 'name4', order: 4, identifier: 'item4', parent_id: item3.id) }
    let(:item5) { custom_report.items.find_or_create_by!(name: 'name5', order: 5, identifier: 'item5', parent_id: item4.id) }
    let(:item_account1) { item1.item_accounts.find_or_create_by!(chart_of_account_id: 1001) }
    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value3) { report_data1.item_values.create!(item_id: item3._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_VARIANCE) }
    let(:item_value4) { report_data1.item_values.create!(item_id: item4._id.to_s, column_id: column._id.to_s, value: 0.0, column_type: Column::TYPE_ACTUAL) }

    describe '#call' do
      it 'creates a new report with items and columns' do
        result = described_class.call(report: custom_report, current_date: '2021-03-01'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(125)
      end

      it 'creates a new report without zero item when is_zero_rows_hidden == true' do
        result = described_class.call(report: custom_report, current_date: '2021-03-01'.to_date, filter: { 'is_zero_rows_hidden' => true })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(25)
      end
    end
  end
end
