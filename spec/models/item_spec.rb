# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Item, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item1) { report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'child_item1', parent_id: parent_item.id.to_s) }
  let(:child_item2) { report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'child_item2', parent_id: parent_item.id.to_s) }
  let(:total_item) { report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'total_item', parent_id: parent_item.id.to_s, totals: true) }
  let(:parent_item2) do
    report.items.find_or_create_by!(
      name: 'Parent Item 3',
      order: 2,
      identifier: 'parent_item2',
      type_config: {
        'name' => Item::TYPE_QUICKBOOKS_LEDGER,
        'use_mapping' => {
          'item_id' => 'child_item1'
        }
      }
    )
  end
  let(:item_account1) { child_item1.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:item_account2) { child_item2.item_accounts.find_or_create_by!(chart_of_account_id: 2, accounting_class_id: 1) }
  let(:item_account3) { parent_item.item_accounts.find_or_create_by!(chart_of_account_id: 3, accounting_class_id: 1) }

  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:report) }
    it { is_expected.to embed_many(:item_accounts) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_presence_of(:identifier) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:order).of_type(Integer) }
    it { is_expected.to have_field(:identifier).of_type(String) }
    it { is_expected.to have_field(:show).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:depth_diff).of_type(Integer) }
    it { is_expected.to have_field(:totals).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:type_config).of_type(Object) }
    it { is_expected.to have_field(:values_config).of_type(Object) }
    it { is_expected.to have_field(:account_type).of_type(String) }
    it { is_expected.to have_field(:negative).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:negative_for_total).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:parent_id).of_type(String) }
  end

  describe '#all_item_accounts' do
    it 'returns all item accounts' do
      item_account1
      item_account2
      item_account3
      expect(child_item2.all_item_accounts.count).to eq(1)
      expect(parent_item.all_item_accounts.count).to eq(3)
    end
  end

  describe '#mapped_item_accounts' do
    it 'returns mapped item accounts' do
      item_account1
      item_account2
      expect(child_item2.mapped_item_accounts.count).to eq(1)
      expect(parent_item2.mapped_item_accounts.count).to eq(1)
      expect(child_item2.mapped_item_accounts[0].chart_of_account_id).to eq(2)
    end

    it 'returns blank for mapped item accounts' do
      expect(parent_item2.mapped_item_accounts.count).to eq(0)
    end
  end

  describe '#item_account_count' do
    it 'returns item_account_count' do
      item_account1
      item_account2
      item_account3
      expect(parent_item.item_account_count).to eq(1)
      expect(total_item.item_account_count).to eq(3)
    end
  end

  describe '#prior_balance_day_option?' do
    let(:priod_day_balance_child_item) do
      item = report.items.create!(name: 'priod_day_balance_child_item', order: 1, identifier: 'priod_day_balance_child_item',
                                  type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE,
                                                 Item::BALANCE_SHEET_OPTIONS => {
                                                   Item::BALANCE_DAY_OPTIONS => Item::PRIOR_BALANCE_DAY
                                                 } },
                                  values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')))
      item.item_accounts.create!(chart_of_account_id: 1001)
      item.item_accounts.create!(chart_of_account_id: 1002)
      item
    end

    it 'returns true if this item is prior balance day' do
      priod_day_balance_child_item
      expect(priod_day_balance_child_item).to be_prior_balance_day_option
    end
  end
end
