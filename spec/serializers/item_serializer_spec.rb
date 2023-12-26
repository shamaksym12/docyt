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

RSpec.describe ItemSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item', type_config: { name: 111 }, values_config: { value: 'actual' }) }
  let(:child_item) do
    report.items.find_or_create_by!(
      name: 'Child Item',
      order: 1,
      identifier: 'child_item',
      type_config: {
        'name' => Item::TYPE_QUICKBOOKS_LEDGER,
        'use_mapping' => {
          'item_id' => 'child_item1'
        }
      },
      parent_id: parent_item.id.to_s
    )
  end
  let!(:item_account) { parent_item.item_accounts.create!(accounting_class_id: 13) }

  it 'contains user information in json' do # rubocop:disable RSpec/MultipleExpectations
    child_item
    json_string = described_class.new(parent_item).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['item']['name']).to eq('name')
    expect(result_hash['item']['identifier']).to eq('parent_item')
    expect(result_hash['item']['depth_diff']).to eq(0)
    expect(result_hash['item']['totals']).not_to be_nil
    expect(result_hash['item']['show']).not_to be_nil
    expect(result_hash['item']['child_items'][0]['use_mapping']).to be_truthy
    expect(result_hash['item']['item_accounts'][0]['accounting_class_id']).to eq(item_account.accounting_class_id)
    expect(result_hash['item']['values_config']).not_to be_nil
  end
end
