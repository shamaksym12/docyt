# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe Api::Internal::ReportValuesController, internal: true do
  before do
    item_value
    item_value1
  end

  let(:service) { DocytLib::Auth::Service.new(service_name: 'External') }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:template_id) { ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID }
  let(:slug) { ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID }
  let(:item_identifier) { ProfitAndLossReport::NET_PROFIT_ITEM_IDENTIFIER }
  let(:period_type) { Report::PERIOD_MONTHLY }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:pl_report) do
    ProfitAndLossReport.create!(report_service: report_service, template_id: template_id, slug: template_id, name: 'name1')
  end
  let(:report_data) { create(:report_data, report: pl_report, start_date: '2023-03-01', end_date: '2023-03-31', period_type: Report::PERIOD_MONTHLY) }
  let(:report_data1) { create(:report_data, report: pl_report, start_date: '2023-04-01', end_date: '2023-04-30', period_type: Report::PERIOD_MONTHLY) }
  let(:item) { pl_report.items.find_or_create_by!(name: 'name', order: 1, identifier: ProfitAndLossReport::NET_PROFIT_ITEM_IDENTIFIER) }
  let(:column) { pl_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:column1) { pl_report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_available', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value) { report_data.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item_identifier) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item._id.to_s, column_id: column1._id.to_s, value: 4.0, item_identifier: item_identifier) }
  let(:from) { '2023-02-01' }
  let(:to) { '2023-04-30' }
  let(:column_year) { 'current' }
  let(:column_type) { 'actual_per_metric' }
  let(:column_per_metric) { 'rooms_available' }

  path '/reports/api/internal/report_values' do
    get 'returns list Net Profit values' do
      include_context 'internal api'
      tags 'Report'
      operationId 'get_report_values'

      parameter name: :business_id, in: :query, type: :string, required: true
      parameter name: :template_id, in: :query, type: :string, required: true
      parameter name: :slug, in: :query, type: :string, required: true
      parameter name: :item_identifier, in: :query, type: :string, required: true
      parameter name: :period_type, in: :query, type: :string, required: true
      parameter name: :from, in: :query, type: :string, required: true
      parameter name: :to, in: :query, type: :string, required: true
      parameter name: :column_year, in: :query, type: :string, required: true
      parameter name: :column_type, in: :query, type: :string, required: true
      parameter name: :column_per_metric, in: :query, type: :string

      response '200', 'returns list successfully' do
        schema type: :object, properties: { report_values: { type: :array, items: { '$ref' => '#/components/schemas/report_value' } } }

        run_test!
      end
    end
  end
end
