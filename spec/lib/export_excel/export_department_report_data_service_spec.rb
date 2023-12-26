# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportDepartmentReportDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      report_service
      item_value1
      item_value2
      item_value3
      item_value4
    end

    let(:user) { Struct.new(:id).new(1) }
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
    let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4', name: 'class01', parent_external_id: nil) }
    let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1', name: 'class02', parent_external_id: nil) }
    let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: 105, external_id: '5', parent_external_id: '1') }
    let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2, sub_class]) }
    let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
    let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi,
                      get_business: business_info,
                      get_business_chart_of_accounts: business_chart_of_accounts_response,
                      get_accounting_classes: accounting_class_response,
                      get_qbo_connection: business_quickbooks_connection_info)
    end
    let(:sheet_row) { Struct.new(:outline_level, :hidden).new(0, false) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view) }

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: Report::DEPARTMENT_REPORT, name: 'name1' }, current_user: user).report
    end
    let(:report_data1) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
    let(:item1) { custom_report.find_item_by_identifier(identifier: 'revenue_1_5') }
    let(:item2) { custom_report.find_item_by_identifier(identifier: 'revenue_4') }
    let(:item3) { custom_report.find_item_by_identifier(identifier: 'revenue_4') }
    let(:revenue_item) { custom_report.find_item_by_identifier(identifier: 'revenue') }
    let(:column) { custom_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0) }
    let(:item_value3) { report_data1.item_values.create!(item_id: revenue_item._id.to_s, column_id: column._id.to_s, value: 7.0) }
    let(:item_value4) { report_data1.item_values.create!(item_id: item3._id.to_s, column_id: column._id.to_s, value: 0.0) }
    let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
    let(:users_response) { Struct.new(:users).new([user_response]) }
    let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }

    describe '#call_department_report_with_period' do
      it 'creates a new report with multiple months' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, filter: { accounting_class_id: 2 })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(26)
      end

      it 'creates a new report with multiple months when ' do
        result = described_class.call(
          report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date,
          filter: { accounting_class_id: 2, 'is_zero_rows_hidden' => true }
        )
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(13)
      end
    end
  end
end
