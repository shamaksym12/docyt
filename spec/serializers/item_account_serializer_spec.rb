# frozen_string_literal: true

# == Mongoid Information
#
# Document name: clients
#
#  id                   :string
#  report_service_id    :integer
#  template_id          :string
#  name                 :string
#

require 'rails_helper'

RSpec.describe ItemAccountSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: parent_item.id.to_s) }
  let(:item_account) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }

  it 'contains user information in json' do
    json_string = described_class.new(item_account).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['item_account']['id']).not_to be_nil
    expect(result_hash['item_account']['chart_of_account_id']).to eq(1)
    expect(result_hash['item_account']['item_id']).to eq(child_item._id.to_s)
  end
end
