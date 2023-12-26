# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BalanceSheetReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) { instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date) }
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', name: 'name1', acc_type: 'Bank', parent_id: nil)
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', name: 'name2', acc_type: 'Accounts Receivable', parent_id: nil)
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '10', name: 'name3', acc_type: 'Other Current Asset', parent_id: nil)
  end
  let(:business_chart_of_account4) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1004, qbo_id: '11', name: 'name4', acc_type: 'Fixed Asset', parent_id: nil)
  end
  let(:business_chart_of_account5) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1005, qbo_id: '11', name: 'name5', acc_type: 'Accounts Payable', parent_id: nil)
  end
  let(:business_chart_of_account6) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1006, qbo_id: '11', name: 'name6', acc_type: 'Credit Card', parent_id: nil)
  end
  let(:business_chart_of_account7) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1007, qbo_id: '11', name: 'name7', acc_type: 'Other Current Liability', parent_id: nil)
  end
  let(:business_chart_of_account8) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1008, qbo_id: '11', name: 'name8', acc_type: 'Long Term Liability', parent_id: nil)
  end
  let(:business_chart_of_account9) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1009, qbo_id: '11', name: 'name9', acc_type: 'Equity', parent_id: 2000)
  end
  let(:business_chart_of_account10) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1010, qbo_id: '11', name: 'name10', acc_type: 'Bank', parent_id: 1001)
  end
  let(:business_chart_of_account11) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1011, qbo_id: '11', name: 'name11', acc_type: 'Bank', parent_id: 1010)
  end
  let(:business_chart_of_accounts) do
    [
      business_chart_of_account1,
      business_chart_of_account2,
      business_chart_of_account3,
      business_chart_of_account4,
      business_chart_of_account5,
      business_chart_of_account6,
      business_chart_of_account7,
      business_chart_of_account8,
      business_chart_of_account9,
      business_chart_of_account10,
      business_chart_of_account11
    ]
  end
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: Struct.new(:accounting_classes).new([]))
  end

  describe '#create' do
    it 'creates a balance sheet report' do
      result = described_class.create(report_service: report_service)
      expect(result).to be_success
      expect(result.report.template_id).to eq(BalanceSheetReport::BALANCE_SHEET_REPORT)
    end

    it 'creates an item of child chart of account when does not exits parent chart of account' do
      result = described_class.create(report_service: report_service)
      items = result.report.items.select { |item| item.name == business_chart_of_account9.name }
      expect(items.first).not_to be_nil
    end

    it 'creates an item of child chart of account when exits parent chart of account' do
      result = described_class.create(report_service: report_service)
      items = result.report.items.select { |item| item.name == business_chart_of_account10.name }
      expect(items.first.identifier).to eq(business_chart_of_account10.chart_of_account_id.to_s)
      expect(items.count).to eq(1)
    end
  end
end
