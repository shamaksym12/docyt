# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemValuesQuery do
  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) do
    AdvancedReport.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1')
  end
  let(:report_data1) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:item_identifier) { Faker::Lorem.characters(12) }
  let(:item) { custom_report.items.find_or_create_by!(identifier: item_identifier, name: item_identifier, order: 1) }
  let(:column1) { custom_report.columns.find_or_create_by!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:column2) { custom_report.columns.find_or_create_by!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
  let(:column3) do
    custom_report.columns.find_or_create_by!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
  end
  let(:item_value1) { report_data1.item_values.create!(item_identifier: item_identifier, item_id: item._id.to_s, column_id: column1._id.to_s, value: 3.0) }
  let(:item_value2) { report_data1.item_values.create!(item_identifier: item_identifier, item_id: item._id.to_s, column_id: column2._id.to_s, value: 4.0) }
  let(:item_value3) { report_data1.item_values.create!(item_identifier: item_identifier, item_id: item._id.to_s, column_id: column3._id.to_s, value: 5.0) }

  describe '#item_values' do
    subject(:item_values_by_period) { described_class.new(report: custom_report, item_values_params: item_values_params).item_values }

    before do
      item_value1
      item_value2
      item_value3
    end

    context 'with one month' do
      let(:item_values_params) do
        {
          from: '2021-03-01',
          to: '2021-03-31',
          item_identifier: item_identifier
        }
      end

      it 'returns 3 item_values' do
        expect(item_values_by_period.length).to eq(3)
      end
    end

    context 'with period' do
      let(:item_values_params) do
        {
          from: '2021-03-01',
          to: '2021-04-30',
          item_identifier: item_identifier
        }
      end

      it 'returns 3 item_values with total item_value' do
        expect(item_values_by_period.length).to eq(3)
      end

      it 'returns 3 item_values with total item_value for balace sheet item' do
        item.update(type_config: { Item::CALCULATION_TYPE_CONFIG => Item::BALANCE_SHEET_CALCULATION_TYPE })
        expect(item_values_by_period.length).to eq(3)
      end

      it 'returns 2 item_values without total item_value' do
        custom_report.update(total_column_visible: false)
        expect(item_values_by_period.length).to eq(2)
      end
    end
  end
end
