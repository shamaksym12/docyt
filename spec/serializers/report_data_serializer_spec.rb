# frozen_string_literal: true

# == Mongoid Information
#
# Document name: ReportDatas
#
#  id                   :string
#  start_date           :Date
#  end_date             :Date
#

require 'rails_helper'

RSpec.describe ReportDataSerializer do
  before do
    item_value1
    item_value2
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) do
    report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31', update_state: Report::UPDATE_STATE_STARTED)
  end
  let(:item1) { report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item') }
  let(:item2) { report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item') }
  let(:column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0) }
  let(:item_value2) { report_data.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0) }

  it 'contains report_data information in json' do # rubocop:disable RSpec/MultipleExpectations
    json_string = described_class.new(report_data).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['report_data']['start_date']).to eq('2021-03-01')
    expect(result_hash['report_data']['end_date']).to eq('2021-03-31')
    expect(result_hash['report_data']['item_values'].size).to eq(2)
    expect(result_hash['report_data']['budget_ids'].size).to eq(0)
    expect(result_hash['report_data']['update_state']).to eq(Report::UPDATE_STATE_STARTED)
    expect(result_hash['report_data']['error_msg']).to be_nil
  end

  describe '#updated_time_string' do
    it 'contains nil' do
      report_data.update(updated_at: nil)
      json_string = described_class.new(report_data).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['report_data']['updated_time_string']).to be_nil
    end

    it 'contains with type - ago' do
      report_data.update(updated_at: 3.hours.ago)
      json_string = described_class.new(report_data).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['report_data']['updated_time_string']).to eq('3 hours ago')
    end

    it 'contains with standard type' do
      report_data.update(updated_at: 3.months.ago)
      json_string = described_class.new(report_data).to_json
      result_hash = JSON.parse(json_string)
      expect(result_hash['report_data']['updated_time_string']).to eq(report_data.updated_at.strftime('%m/%d/%Y'))
    end
  end
end
