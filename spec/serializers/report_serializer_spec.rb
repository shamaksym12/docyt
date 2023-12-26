# frozen_string_literal: true

# == Mongoid Information
#
# Document name: reports
#
#  id                   :string
#  report_service_id    :integer
#  template_id          :string
#  name                 :string
#

require 'rails_helper'

RSpec.describe ReportSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) do
    Report.create!(
      report_service: report_service,
      template_id: 'owners_operating_statement',
      slug: 'owners_operating_statement',
      name: 'name1',
      update_state: Report::UPDATE_STATE_QUEUED,
      enabled_budget_compare: true
    )
  end

  it 'contains report information in json' do # rubocop:disable RSpec/MultipleExpectations
    json_string = described_class.new(report).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['report']['id']).not_to be_nil
    expect(result_hash['report']['template_id']).to eq('owners_operating_statement')
    expect(result_hash['report']['slug']).to eq('owners_operating_statement')
    expect(result_hash['report']['item_accounts_count']).to eq(0)
    expect(result_hash['report']['update_state']).to eq(Report::UPDATE_STATE_QUEUED)
    expect(result_hash['report']['enabled_budget_compare']).to be_truthy
    expect(result_hash['report']['total_column_visible']).to be_truthy
    expect(result_hash['report']['enabled_default_mapping']).to be_falsy
    expect(result_hash['report']['edit_mapping_disabled']).to be_falsy
    expect(result_hash['report']['period_type']).to eq(Report::PERIOD_MONTHLY)
    expect(result_hash['report']['accepted_accounting_class_ids'].count).to eq(0)
    expect(result_hash['report']['accepted_chart_of_account_ids'].count).to eq(0)
  end

  it 'contains user information in json' do
    json_string = described_class.new(report).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['report']['accessible_user_ids']).not_to be_nil
  end
end
