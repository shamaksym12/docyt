# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemValue, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, period_type: ReportData::PERIOD_MONTHLY) }

  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:report_data) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:column_id).of_type(String) }
    it { is_expected.to have_field(:item_id).of_type(String) }
    it { is_expected.to have_field(:value).of_type(Float) }
    it { is_expected.to have_field(:column_type).of_type(String) }
    it { is_expected.to have_field(:item_identifier).of_type(String) }
    it { is_expected.to have_field(:budget_values).of_type(Array) }
  end

  describe '#generate_column_type' do
    let(:item1) { custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
    let(:item2) { custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_METRIC }) }
    let(:item3) do
      custom_report.items.find_or_create_by!(
        name: 'name3',
        order: 3,
        identifier: 'parent_item',
        values_config: { 'actual' => { 'value' => { 'expression' => { 'operator' => '%' } } } }
      )
    end
    let(:column1) { custom_report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:column2) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }

    it 'generates percentage column type' do
      item_value = report_data.item_values.create!(item_id: item1._id.to_s, column_id: column1._id.to_s, value: 3.0)
      item_value.generate_column_type
      expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
    end

    it 'generates percentage column type for percent operator item' do
      item_value = report_data.item_values.create!(item_id: item3._id.to_s, column_id: column2._id.to_s, value: 3.2)
      item_value.generate_column_type
      expect(item_value.column_type).to eq(Column::TYPE_PERCENTAGE)
    end

    it 'generates rounded value column type' do
      item_value = report_data.item_values.create!(item_id: item2._id.to_s, column_id: column2._id.to_s, value: 3.2)
      item_value.generate_column_type
      expect(item_value.column_type).to eq(Column::TYPE_VARIANCE)
    end

    it 'generates dollar signed column type' do
      item_value = report_data.item_values.create!(item_id: item1._id.to_s, column_id: column2._id.to_s, value: 3.2)
      item_value.generate_column_type
      expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
    end
  end
end
