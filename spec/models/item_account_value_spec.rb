# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemAccountValue, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, period_type: ReportData::PERIOD_MONTHLY) }

  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:report_data) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:item_id) }
    it { is_expected.to validate_presence_of(:column_id) }
    it { is_expected.to validate_presence_of(:chart_of_account_id) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:item_id).of_type(String) }
    it { is_expected.to have_field(:column_id).of_type(String) }
    it { is_expected.to have_field(:chart_of_account_id).of_type(Integer) }
    it { is_expected.to have_field(:accounting_class_id).of_type(Integer) }
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:value).of_type(Float) }
    it { is_expected.to have_field(:column_type).of_type(String) }
  end

  describe '#line_item_details' do
    before do
      allow(Quickbooks::LineItemDetailsQuery).to receive(:new).and_return(line_item_details_query)
    end

    let(:item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
    let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:line_item_detail) { Quickbooks::LineItemDetail.new(amount: 10.0) }
    let(:line_item_details_query) { instance_double(Quickbooks::LineItemDetailsQuery, by_period: [line_item_detail]) }
    let(:item_account_value) do
      described_class.new(item_id: item.id.to_s, column_id: column.id.to_s, chart_of_account_id: 333, accounting_class_id: 10,
                          value: 10.0, name: 'test item value', report_data: report_data)
    end

    it 'returns array of line_item_detail' do
      line_item_details = item_account_value.line_item_details(page: 1)
      expect(line_item_details.length).to eq(1)
      expect(line_item_details[0].amount).to eq(10.0)
    end

    it 'calls Quickbooks::LineItemDetailsQuery to fetch line items' do
      item_account_value.line_item_details(page: 1)
      expect(line_item_details_query).to have_received(:by_period)
    end
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
      item_account_value = report_data.item_account_values.create!(item_id: item1._id.to_s, column_id: column1._id.to_s, chart_of_account_id: 333, value: 3.0)
      item_account_value.generate_column_type
      expect(item_account_value.column_type).to eq(Column::TYPE_PERCENTAGE)
    end

    it 'generates percentage column type for percent operator item' do
      item_account_value = report_data.item_account_values.create!(item_id: item3._id.to_s, column_id: column2._id.to_s, chart_of_account_id: 333, value: 3.2)
      item_account_value.generate_column_type
      expect(item_account_value.column_type).to eq(Column::TYPE_PERCENTAGE)
    end

    it 'generates rounded value column type' do
      item_account_value = report_data.item_account_values.create!(item_id: item2._id.to_s, column_id: column2._id.to_s, chart_of_account_id: 333, value: 3.2)
      item_account_value.generate_column_type
      expect(item_account_value.column_type).to eq(Column::TYPE_VARIANCE)
    end

    it 'generates dollar signed column type' do
      item_account_value = report_data.item_account_values.create!(item_id: item1._id.to_s, column_id: column2._id.to_s, chart_of_account_id: 333, value: 3.2)
      item_account_value.generate_column_type
      expect(item_account_value.column_type).to eq(Column::TYPE_ACTUAL)
    end
  end
end
