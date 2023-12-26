# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemAccountFactory do
  before do
    allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item) do
    report.items.find_or_create_by!(
      name: 'name',
      order: 1,
      identifier: 'child_item',
      type_config: {
        'name' => Item::TYPE_QUICKBOOKS_LEDGER,
        'default_accounts' => [
          {
            'account_type' => 'acc_type1',
            'account_detail_type' => 'sub_type1'
          },
          {
            'account_type' => 'acc_type2',
            'account_detail_type' => 'sub_type2'
          },
          {
            'account_type' => 'acc_type3',
            'account_detail_type' => 'sub_type3'
          },
          {
            'account_type' => 'acc_type4',
            'account_detail_type' => 'sub_type4'
          }
        ]
      },
      parent_id: parent_item.id.to_s
    )
  end
  let(:item_account) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:item_account_value) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1001, accounting_class_id: 1) }
  let(:item_account_value1) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1002) }

  let(:tar_business_id) { Faker::Number.number(digits: 10) }
  let(:tar_service_id) { Faker::Number.number(digits: 10) }
  let(:tar_report_service) { ReportService.create!(service_id: tar_service_id, business_id: tar_business_id) }
  let(:tar_custom_report) { Report.create!(report_service: tar_report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:tar_parent_item) { tar_custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:tar_child_item) { tar_custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: tar_parent_item.id.to_s) }
  let(:business_advisor_response) { Struct.new(:id, :business_id).new(1, 105) }
  let(:business_advisor_info) { instance_double(DocytServerClient::BusinessAdvisorInfo, business_advisor: business_advisor_response) }
  let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_business_advisor: business_advisor_info) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', mapped_class_ids: [1, 2, 3], display_name: 'name1',
                    acc_type_name: 'acc_type1', sub_type: 'sub_type1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', mapped_class_ids: [1, 2, 3], display_name: 'name2',
                    acc_type_name: 'acc_type2', sub_type: 'sub_type2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', mapped_class_ids: [1, 2, 3], display_name: 'name3',
                    acc_type_name: 'acc_type3', sub_type: 'sub_type3')
  end
  let(:business_chart_of_account4) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1004, qbo_id: '101', mapped_class_ids: [1, 2, 3], display_name: 'name4',
                    acc_type_name: 'acc_type4', sub_type: nil)
  end
  let(:business_all_chart_of_account_info) do
    Struct.new(:business_chart_of_accounts)
          .new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3, business_chart_of_account4])
  end
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4', name: '1') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1', name: '2') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business_chart_of_accounts: business_all_chart_of_account_info,
                    get_all_business_chart_of_accounts: business_all_chart_of_account_info,
                    get_accounting_classes: accounting_class_response)
  end

  describe '#create_batch' do
    let(:maps) do
      [
        { chart_of_account_id: 3, accounting_class_id: 2 },
        { chart_of_account_id: 2, accounting_class_id: 2 },
        { chart_of_account_id: 3, accounting_class_id: 2 },
        { chart_of_account_id: 3, accounting_class_id: 1 }
      ]
    end

    it 'creates new items only for non-duplicated maps' do
      result = described_class.create_batch(current_item: child_item, maps: maps)
      expect(result).to be_success
      expect(child_item.reload.item_accounts.count).to eq(3)
    end
  end

  describe '#destroy_batch' do
    it 'destroys the items' do
      result = described_class.destroy_batch(item_accounts: [item_account])
      expect(result).to be_success
    end
  end

  describe '#copy_mapping' do
    it 'creates new items only for non-duplicated maps' do
      item_account_value
      item_account_value1
      tar_child_item
      result = described_class.copy_mapping(src_report: report, target_report: tar_custom_report)
      expect(result).to be_success
      expect(tar_child_item.reload.item_accounts.count).to eq(2)
    end
  end

  describe '#load_default_mapping' do
    it 'deletes existing item_accounts and creates default_accounts' do
      child_item
      item_account
      item_account_value
      result = described_class.load_default_mapping(report: report)
      expect(result).to be_success
      expect(child_item.reload.item_accounts.count).to eq(3)
      expect(report.accepted_chart_of_account_ids.count).to eq(3)
    end
  end
end
