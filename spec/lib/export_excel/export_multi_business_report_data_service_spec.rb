# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportMultiBusinessReportDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      item_value1
      item_value2
      item_value3
      item_value4
      item_value5
      item_value6
      item_value7
      percentage_column
      multi_custom_report
      columns
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
    let(:report_data1) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data2) { create(:report_data, report: custom_report, start_date: '2021-04-01', end_date: '2021-04-30', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data3) { create(:report_data, report: custom_report, start_date: '2021-03-11', end_date: '2021-03-11', period_type: ReportData::PERIOD_MONTHLY) }
    let(:business_response) do
      instance_double(DocytServerClient::Business, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month), display_name: 'My Business', name: 'My Business')
    end
    let(:business_info) { OpenStruct.new(business: business_response) }
    let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_business: business_info) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: true, merge_cells: true) }
    let(:item1) { custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
    let(:item2) { custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item') }
    let(:child_item) { custom_report.items.find_or_create_by!(name: 'name3', order: 3, identifier: 'child_item', parent_id: item1.id) }
    let(:actual_column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:percentage_column) { custom_report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: actual_column._id.to_s, value: 3.0) }
    let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: actual_column._id.to_s, value: 4.0) }
    let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: actual_column._id.to_s, value: 3.0) }
    let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: actual_column._id.to_s, value: 4.0) }
    let(:item_value5) { report_data3.item_values.create!(item_id: item1._id.to_s, column_id: actual_column._id.to_s, value: 3.0) }
    let(:item_value6) { report_data3.item_values.create!(item_id: item2._id.to_s, column_id: actual_column._id.to_s, value: 4.0) }
    let(:item_value7) { report_data1.item_values.create!(item_id: child_item._id.to_s, column_id: actual_column._id.to_s, value: 1.0) }
    let(:multi_custom_report) do
      MultiBusinessReport.create!(multi_business_report_service_id: 111,
                                  template_id: 'owners_operating_statement', name: 'name1', report_ids: [custom_report.id])
    end
    let(:column1) { multi_custom_report.columns.create!(name: '$', type: Column::TYPE_ACTUAL) }
    let(:column2) { multi_custom_report.columns.create!(name: '%', type: Column::TYPE_PERCENTAGE) }
    let(:columns) { [column1, column2] }

    describe '#call' do
      it 'creates a new report with multi monthly custom report' do
        result = described_class.call(multi_business_report: multi_custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(10)
      end

      it 'creates a new report with multi daily custom report' do
        result = described_class.call(multi_business_report: multi_custom_report, start_date: '2021-03-11'.to_date, end_date: '2021-03-11'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(10)
      end

      it 'creates a new report without zero item when is_zero_rows_hidden == true' do
        result = described_class.call(
          multi_business_report: multi_custom_report, start_date: '2021-03-11'.to_date, end_date: '2021-03-11'.to_date,
          filter: { 'is_zero_rows_hidden' => true }
        )
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(5)
      end
    end
  end
end
