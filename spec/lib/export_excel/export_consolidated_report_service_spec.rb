# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportConsolidatedReportService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
      item_value1
      item_value2
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:custom_report1) do
      Report.create!(report_service: report_service, template_id: 'owners_operating_statement',
                     slug: 'owners_operating_statement', name: 'owners_operating_statementme1')
    end
    let(:custom_report2) do
      Report.create!(report_service: report_service, template_id: 'operators_operating_statement',
                     slug: 'operators_operating_statement', name: 'operators_operating_statement')
    end
    let(:report_data1) { create(:report_data, report: custom_report1, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:report_data2) { create(:report_data, report: custom_report2, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
    let(:last_reconciled_month_data) { Struct.new(:year, :month, :status).new(2021, 1, 'reconciled') }
    let(:business_response) do
      instance_double(DocytServerClient::BusinessDetail, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month),
                                                         display_name: 'My Business', name: 'My Business', last_reconciled_month_data: last_reconciled_month_data)
    end
    let(:business_info) { Struct.new(:business).new(business_response) }
    let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_business: business_info) }
    let(:cell) { Struct.new(:value, :style).new('Rooms Sold', nil) }
    let(:sheet_row) { instance_double(Axlsx::Row, outline_level: 0, hidden: false, add_cell: cell) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view) }
    let(:item1) { custom_report1.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
    let(:item2) { custom_report2.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
    let(:column1) { custom_report1.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:column2) { custom_report2.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT, name: 'PTD $') }
    let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column1._id.to_s, value: 3.0) }
    let(:item_value2) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column2._id.to_s, value: 4.0) }

    describe '#call' do
      it 'creates a new consolidated report' do
        result = described_class.call(report_service: report_service, reports: [custom_report1, custom_report2], start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date)
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(20)
      end
    end
  end
end
