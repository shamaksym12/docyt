# frozen_string_literal: true

require 'rails_helper'

module ExportExcel # rubocop:disable Metrics/ModuleLength
  RSpec.describe ExportReportDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      allow(sheet_row).to receive(:outline_level=).with(anything)
      allow(sheet_row).to receive(:hidden=).with(anything)
      item_value1
      item_value2
      item_value3
      item_value4
      item_value9
      item_value5
      item_value6
      item_value7
      item_account_value1
      item_account_value2
      item_account_value3
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report) do
      AdvancedReport.create!(report_service: report_service, template_id: 'owners_operating_statement',
                             slug: 'owners_operating_statement', name: 'name1', view_by_options: ['rooms_sold'])
    end
    let(:custom_report2) do
      AdvancedReport.create!(report_service: report_service, template_id: 'qsr_balance_sheet',
                             slug: 'qsr_balance_sheet', name: 'name1', view_by_options: ['rooms_sold'])
    end
    let(:report_data1) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data2) { create(:report_data, report: custom_report, start_date: '2021-04-01', end_date: '2021-04-30', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data3) { create(:report_data, report: custom_report2, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
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
    let(:cell) { Struct.new(:value, :style).new('Rooms Sold', nil) }
    let(:sheet_row) { instance_double(Axlsx::Row, outline_level: 0, hidden: false, add_cell: cell) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view, merge_cells: true) }
    let(:item1) { custom_report.items.find_or_create_by!(name: 'Rooms Sold', order: 1, identifier: 'parent_item') }
    let(:item2) do
      custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'child_item_1',
                                             type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: item1.id)
    end
    let(:item_account1) { item2.item_accounts.find_or_create_by!(chart_of_account_id: 1001) }
    let(:item_account2) { item2.item_accounts.find_or_create_by!(chart_of_account_id: 1002) }
    let(:item_account3) { item2.item_accounts.find_or_create_by!(chart_of_account_id: 1003) }
    let(:item3) do
      custom_report.items.find_or_create_by!(name: 'name3', order: 3, identifier: 'child_item_2',
                                             type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: item1.id)
    end
    let(:item4) { custom_report2.items.find_or_create_by!(name: 'Rooms Sold', order: 1, identifier: 'parent_item') }
    let(:item5) do
      custom_report2.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'child_item_1',
                                              type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: item4.id)
    end

    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:column1) { custom_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'Budget') }
    let(:column2) { custom_report2.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, column_type: Column::TYPE_PERCENTAGE) }
    let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value9) { report_data1.item_values.create!(item_id: item3._id.to_s, column_id: column._id.to_s, value: 4.0, column_type: Column::TYPE_VARIANCE) }
    let(:item_value5) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column1._id.to_s, value: 4.0, column_type: Column::TYPE_BUDGET_ACTUAL) }
    let(:item_value6) { report_data3.item_values.create!(item_id: item4._id.to_s, column_id: column2._id.to_s, value: 3.0, column_type: Column::TYPE_ACTUAL) }
    let(:item_value7) { report_data3.item_values.create!(item_id: item5._id.to_s, column_id: column2._id.to_s, value: 3.0, column_type: Column::TYPE_ACTUAL) }

    let(:item_account_value1) do
      report_data1.item_account_values.find_or_create_by!(item_id: item2._id, column_id: column._id, chart_of_account_id: item_account1.chart_of_account_id,
                                                          name: 'test1', value: 2)
    end
    let(:item_account_value2) do
      report_data1.item_account_values.find_or_create_by!(item_id: item2._id, column_id: column._id, chart_of_account_id: item_account2.chart_of_account_id,
                                                          name: 'test2', value: 2)
    end
    let(:item_account_value3) do
      report_data1.item_account_values.find_or_create_by!(item_id: item2._id, column_id: column._id, chart_of_account_id: item_account3.chart_of_account_id,
                                                          name: 'test3', value: 0)
    end

    let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
    let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2020) }

    describe '#call' do
      it 'creates a new report with items and columns' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(27)
      end

      it 'creates excel with items and columns for store manager report' do
        custom_report.update(template_id: Report::STORE_MANAGERS_REPORT)
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(29)
      end

      it 'creates excel with items and columns and selected budget' do
        custom_report.update(template_id: Report::STORE_MANAGERS_REPORT)
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, filter: { 'budget' => budget2.id.to_s })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(29)
      end

      it 'creates a new report without zero item when is_zero_rows_hidden == true' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, filter: { 'is_zero_rows_hidden' => true })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(26)
      end
    end

    describe '#call_with_period' do
      it 'creates a new report with multiple months' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-04-30'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(45)
      end

      it 'creates a new report with multiple months when is_zero_rows_hidden == true' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-04-30'.to_date, filter: { 'is_zero_rows_hidden' => true })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(39)
      end

      it 'creates a new report with total value of each chart of account' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-04-30'.to_date)
        expect(result).to be_success

        exported_content = []
        expect(work_sheet_instance).to have_received(:add_row).at_least(:once) do |row|
          exported_content << row
        end

        total_business_chart_of_account1 = exported_content[9][1]
        expect(total_business_chart_of_account1).to eq(2.0)
      end
    end

    describe 'creates a new report with items and columns and tests the exported main column position' do
      it 'export report with main column in the center' do
        result = described_class.call(report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success

        exported_content = []
        expect(work_sheet_instance).to have_received(:add_row).at_least(:once) do |row|
          exported_content << row
        end
        header_center_column_value = exported_content[0][1]
        body_center_column_value = exported_content[7][1]
        expect(header_center_column_value).to eq('Company: My Business')
        expect(body_center_column_value).to eq('Rooms Sold')
      end

      it 'export report with the main column position to the left' do
        result = described_class.call(report: custom_report2, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success

        exported_content = []
        expect(work_sheet_instance).to have_received(:add_row).at_least(:once) do |row|
          exported_content << row
        end
        header_left_column_value = exported_content[0][0]
        body_left_column_value = exported_content[7][0]
        expect(header_left_column_value).to eq('Company: My Business')
        expect(body_left_column_value).to eq('Rooms Sold')
      end

      it 'export report with item_name of number formate' do
        item4.update(name: '007')
        result = described_class.call(report: custom_report2, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success

        exported_content = []
        expect(work_sheet_instance).to have_received(:add_row).at_least(:once) do |row|
          exported_content << row
        end
        body_left_column_value = exported_content[7][0]
        expect(body_left_column_value).to eq('007')
      end
    end
  end
end
