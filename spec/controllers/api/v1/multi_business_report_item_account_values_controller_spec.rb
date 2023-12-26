# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::MultiBusinessReportItemAccountValuesController do
  before do
    item_account_value1
    item_account_value2
    second_item_account_value1
    second_item_account_value2
    allow_any_instance_of(described_class).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
    allow(MultiBusinessReportFactory).to receive(:new).and_return(report_factory_instance)
    allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
    allow_any_instance_of(described_class).to receive(:secure_user).and_return(secure_user) # rubocop:disable RSpec/AnyInstance
    allow(ExportExcel::ExportMultiBusinessReportDataService).to receive(:new).and_return(export_multi_business_report_data_service_instance)
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
  end

  let(:secure_user) { Struct.new(:id).new(222) }
  let(:multi_business_report_service) { Struct.new(:id, :consumer_id).new(111, 222) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_report_service) }

  let(:business_id1) { Faker::Number.number(digits: 10) }
  let(:service_id1) { Faker::Number.number(digits: 10) }
  let(:report_service1) { ReportService.create!(service_id: service_id1, business_id: business_id1) }
  let(:owners_report) { Report.create!(report_service: report_service1, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) { create(:report_data, report: owners_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:parent_item) { owners_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true) }
  let(:item1) do
    item = owners_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1', parent_id: parent_item.id.to_s)
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1)
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 2)
    item
  end
  let(:column) { owners_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_account_value1) { report_data.item_account_values.create!(item_id: item1._id, column_id: column._id, chart_of_account_id: 1, accounting_class_id: 1, value: 1.0) }
  let(:item_account_value2) { report_data.item_account_values.create!(item_id: item1._id, column_id: column._id, chart_of_account_id: 2, accounting_class_id: 1, value: 2.0) }

  let(:business_id2) { Faker::Number.number(digits: 10) }
  let(:service_id2) { Faker::Number.number(digits: 10) }
  let(:report_service2) { ReportService.create!(service_id: service_id2, business_id: business_id2) }
  let(:second_report) { Report.create!(report_service: report_service2, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:second_report_data) { create(:report_data, report: second_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:second_parent_item) do
    second_report.items.create!(name: 'second_parent_item', order: 2, identifier: 'second_parent_item',
                                type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, totals: true)
  end
  let(:second_item1) do
    item = second_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'name1', parent_id: second_parent_item.id.to_s)
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1)
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 2)
    item
  end
  let(:second_column) { second_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:second_item_account_value1) do
    second_report_data.item_account_values.create!(item_id: second_item1._id, column_id: second_column._id, chart_of_account_id: 1, accounting_class_id: 1, value: 1.0)
  end
  let(:second_item_account_value2) do
    second_report_data.item_account_values.create!(item_id: second_item1._id, column_id: second_column._id, chart_of_account_id: 2, accounting_class_id: 1, value: 2.0)
  end

  let(:custom_multi_business_report) do
    MultiBusinessReport.create!(report_ids: [owners_report.id, second_report.id], multi_business_report_service_id: 111,
                                template_id: 'owners_operating_statement', name: 'name1')
  end
  let(:report_factory_instance) do
    instance_double(MultiBusinessReportFactory, multi_business_report: custom_multi_business_report, create: true, update_report: true, success?: true)
  end
  let(:export_multi_business_report_data_service_instance) do
    instance_double(ExportExcel::ExportMultiBusinessReportDataService, call: true, report_file_path: 'spec/fixtures/files/a.xlsx', success?: true)
  end
  let(:business_advisor_response) { Struct.new(:id, :business_id).new(1, business_id1) }
  let(:business_advisors) { Struct.new(:business_advisors).new([business_advisor_response]) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id1, bookkeeping_start_date: (Time.zone.today - 1.month))
  end
  let(:businesses_response) { Struct.new(:businesses).new([business_response]) }
  let(:businesses_api_instance) do
    instance_double(DocytServerClient::BusinessesApi, get_by_ids: businesses_response)
  end

  describe 'GET #item_account_values' do
    subject(:item_account_values_response) do
      get :item_account_values, params: params
    end

    let(:params) do
      {
        multi_business_report_id: custom_multi_business_report._id,
        from: '2021-02-01',
        to: '2021-02-28',
        item_identifier: 'name1'
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        item_account_values_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      let(:multi_business_report_service) { Struct.new(:id, :consumer_id).new(11, 222) }
      let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_report_service) }

      it 'returns 403 response when the user has no permission' do
        allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
        item_account_values_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
