# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MigrateToAcceptedChartOfAccountsService do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
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
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business_chart_of_accounts: business_all_chart_of_account_info,
                    get_all_business_chart_of_accounts: business_all_chart_of_account_info)
  end

  describe '#migrate' do
    before do
      report.update(accepted_account_types: [{ 'account_type' => 'acc_type1', 'account_detail_type' => 'sub_type1' },
                                             { 'account_type' => 'acc_type2', 'account_detail_type' => 'sub_type2' },
                                             { 'account_type' => 'acc_type3', 'account_detail_type' => 'sub_type3' }])
    end

    it 'migrate accepted account types to accepted chart of account ids' do
      described_class.migrate(report: report)
      expect(report.accepted_chart_of_account_ids.count).to eq(3)
      expect(report.accepted_chart_of_account_ids[0]).to eq(1001)
    end
  end
end
