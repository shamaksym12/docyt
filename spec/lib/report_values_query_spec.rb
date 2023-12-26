# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportValuesQuery do
  let(:service) { DocytLib::Auth::Service.new(service_name: 'External') }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:template_id) { ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID }
  let(:item_identifier) { ProfitAndLossReport::NET_PROFIT_ITEM_IDENTIFIER }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:pl_report) do
    ProfitAndLossReport.create!(report_service: report_service, template_id: template_id, slug: template_id, name: 'name1')
  end
  let(:report_data1) { create(:report_data, report: pl_report, start_date: '2023-03-01', end_date: '2023-03-31', period_type: Report::PERIOD_MONTHLY) }
  let(:report_data2) { create(:report_data, report: pl_report, start_date: '2023-04-01', end_date: '2023-04-30', period_type: Report::PERIOD_MONTHLY) }
  let(:report_data3) { create(:report_data, report: pl_report, start_date: '2023-04-05', end_date: '2023-04-05', period_type: Report::PERIOD_DAILY) }
  let(:report_data4) { create(:report_data, report: pl_report, start_date: '2023-01-01', end_date: '2023-01-31', period_type: Report::PERIOD_MONTHLY) }
  let(:item) { pl_report.items.find_or_create_by!(name: 'name', order: 1, identifier: item_identifier) }
  let(:column) { pl_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:column1) { pl_report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, per_metric: 'rooms_available', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item_identifier) }
  let(:item_value2) { report_data2.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: item_identifier) }
  let(:item_value3) { report_data3.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 5.0, item_identifier: item_identifier) }
  let(:item_value4) { report_data4.item_values.create!(item_id: item._id.to_s, column_id: column1._id.to_s, value: 6.0, item_identifier: item_identifier) }
  let(:column_type) { nil }
  let(:column_per_metric) { nil }

  describe '#report_values' do
    subject(:report_values_by_period) { described_class.new(report_service: report_service, report_values_params: report_values_params).report_values }

    before do
      item_value1
      item_value2
      item_value3
      item_value4
    end

    let(:report_values_params) do
      {
        business_id: business_id,
        from: '2023-01-01',
        to: '2023-12-31',
        item_identifier: item_identifier,
        period_type: period_type,
        slug: template_id,
        column_type: column_type,
        column_per_metric: column_per_metric
      }
    end

    context 'with period_type = monthly' do
      let(:period_type) { Report::PERIOD_MONTHLY }

      it 'returns 2 report values' do
        expect(report_values_by_period.length).to eq(2)
      end
    end

    context 'with period_type = daily' do
      let(:period_type) { Report::PERIOD_DAILY }

      it 'returns a report value' do
        expect(report_values_by_period.length).to eq(1)
        expect(report_values_by_period[0][:date]).to eq(report_data3.start_date)
        expect(report_values_by_period[0][:amount]).to eq(item_value3.value)
      end
    end

    context 'with column_type and column_per_metric' do
      let(:period_type) { Report::PERIOD_MONTHLY }
      let(:column_type) { Column::TYPE_ACTUAL_PER_METRIC }
      let(:column_per_metric) { 'rooms_available' }

      it 'returns a report value' do
        expect(report_values_by_period.length).to eq(1)
        expect(report_values_by_period[0][:date]).to eq(report_data4.start_date)
        expect(report_values_by_period[0][:amount]).to eq(item_value4.value)
      end
    end
  end

  describe '#empty report_values' do
    let(:report_values_params) do
      {
        business_id: business_id,
        from: '2023-01-01',
        to: '2023-12-31',
        item_identifier: item_identifier,
        period_type: Report::PERIOD_MONTHLY,
        slug: 'owners_operating_statement',
        column_type: column_type,
        column_per_metric: column_per_metric
      }
    end

    it 'returns empty report values' do
      report_values = described_class.new(report_service: report_service, report_values_params: report_values_params).report_values
      expect(report_values).to be_empty
    end
  end
end
