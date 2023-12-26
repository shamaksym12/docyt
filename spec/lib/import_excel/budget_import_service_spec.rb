# frozen_string_literal: true

require 'rails_helper'

module ImportExcel # rubocop:disable Metrics/ModuleLength
  RSpec.describe BudgetImportService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Roo::Spreadsheet).to receive(:open).and_return(spread_sheet_instance)
      allow_any_instance_of(BudgetItemFactory).to receive(:upsert_item).and_return(true) # rubocop:disable RSpec/AnyInstance
      stub_request(:get, /.*internal.*by_token*/).to_return(status: 200, body: '{"file": {"id": "77"}}', headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, /.*internal.*signed_url*/).to_return(status: 200, body: '{"url": "https://test.com/test1"}', headers: { 'Content-Type' => 'application/json' })
      stub_request(:delete, 'https://storage-service.localhost.docyt.com/storage/api/internal/files/77')
        .to_return(status: 200, body: '{}', headers: { 'Content-Type' => 'application/json' })
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 207) }
    let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }
    let(:import_budget) { ImportBudget.create!(budget: budget, imported_file_token: 'test') }
    let(:business_chart_of_account1) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 1, business_id: 105, chart_of_account_id: 1001, display_name: 'test1', acc_type_name: 'test1')
    end
    let(:business_chart_of_account2) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 2, business_id: 105, chart_of_account_id: 1002, display_name: 'test2', acc_type_name: 'test2')
    end
    let(:business_chart_of_account3) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 3, business_id: 105, chart_of_account_id: 1003, display_name: 'test3', acc_type_name: 'test3')
    end
    let(:business_chart_of_accounts) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
    let(:business_response) do
      instance_double(DocytServerClient::BusinessDetail, id: 1, bookkeeping_start_date: (Time.zone.today - 1.month),
                                                         display_name: 'My Business', name: 'My Business')
    end
    let(:business_info) { Struct.new(:business).new(business_response) }
    let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4', name: 'class01', parent_external_id: nil) }
    let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1', name: 'class02', parent_external_id: nil) }
    let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: 105, external_id: '5', parent_external_id: '1') }
    let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
    let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi, get_business: business_info, search_business_chart_of_accounts: business_chart_of_accounts,
                                                      get_business_chart_of_accounts: business_chart_of_accounts_response, get_accounting_classes: accounting_class_response)
    end
    let(:xlsx_file) { 'spec/fixtures/files/imported_temp.xlsx' }
    let(:spread_sheet_instance) { Roo::Spreadsheet.open(xlsx_file) }
    let(:standard_metric1) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
    let(:standard_metric2) { StandardMetric.create!(name: 'Rooms Sold', type: 'Available Rooms', code: 'rooms_available') }
    let(:budget_item1) do
      DraftBudgetItem.create!(
        budget_id: budget.id,
        standard_metric_id: standard_metric1.id.to_s,
        budget_item_values: [
          { month: 1, value: 10 },
          { month: 2, value: 10 },
          { month: 3, value: 10 },
          { month: 4, value: 10 },
          { month: 5, value: 10 },
          { month: 6, value: 10 },
          { month: 7, value: 10 },
          { month: 8, value: 10 },
          { month: 9, value: 10 },
          { month: 10, value: 10 },
          { month: 11, value: 10 },
          { month: 12, value: 10 }
        ]
      )
    end
    let(:budget_item2) do
      DraftBudgetItem.create!(
        budget_id: budget.id,
        standard_metric_id: standard_metric2.id.to_s,
        budget_item_values: [
          { month: 1, value: 10 },
          { month: 2, value: 10 },
          { month: 3, value: 10 },
          { month: 4, value: 10 },
          { month: 5, value: 10 },
          { month: 6, value: 10 },
          { month: 7, value: 10 },
          { month: 8, value: 10 },
          { month: 9, value: 10 },
          { month: 10, value: 10 },
          { month: 11, value: 10 },
          { month: 12, value: 10 }
        ]
      )
    end
    let(:budget_item3) do
      DraftBudgetItem.create!(
        budget_id: budget.id,
        chart_of_account_id: business_chart_of_account1.chart_of_account_id,
        budget_item_values: []
      )
    end
    let(:budget_item4) do
      DraftBudgetItem.create!(
        budget_id: budget.id,
        chart_of_account_id: business_chart_of_account2.chart_of_account_id,
        budget_item_values: []
      )
    end
    let(:budget_item5) do
      DraftBudgetItem.create!(
        budget_id: budget.id,
        chart_of_account_id: business_chart_of_account3.chart_of_account_id,
        budget_item_values: []
      )
    end
    let(:budget_item_params_response1) { budget_item1.budget_item_values }
    let(:budget_item_params_response2) { budget_item2.budget_item_values }
    let(:budget_item_params_response3) { budget_item3.budget_item_values }
    let(:budget_item_params_response4) { budget_item4.budget_item_values }
    let(:budget_item_params_response5) { budget_item5.budget_item_values }
    let(:budget_item_upsert_response1) { BudgetItemFactory.upsert_item(current_budget: budget, budget_item_params: { id: budget_item1.id.to_s, budget_item_values: budget_item_params_response1 }) } # rubocop:disable Layout/LineLength
    let(:budget_item_upsert_response2) { BudgetItemFactory.upsert_item(current_budget: budget, budget_item_params: { id: budget_item2.id.to_s, budget_item_values: budget_item_params_response2 }) } # rubocop:disable Layout/LineLength
    let(:budget_item_upsert_response3) { BudgetItemFactory.upsert_item(current_budget: budget, budget_item_params: { id: budget_item3.id.to_s, budget_item_values: budget_item_params_response3 }) } # rubocop:disable Layout/LineLength
    let(:budget_item_upsert_response4) { BudgetItemFactory.upsert_item(current_budget: budget, budget_item_params: { id: budget_item4.id.to_s, budget_item_values: budget_item_params_response4 }) } # rubocop:disable Layout/LineLength
    let(:budget_item_upsert_response5) { BudgetItemFactory.upsert_item(current_budget: budget, budget_item_params: { id: budget_item5.id.to_s, budget_item_values: budget_item_params_response5 }) } # rubocop:disable Layout/LineLength

    describe '#call' do
      it 'creates a new budget import' do
        budget_item1
        budget_item2
        budget_item3
        budget_item4
        budget_item5
        business_chart_of_accounts
        result = described_class.call(import_budget: import_budget)
        expect(result).to be_success
        expect(budget_item_upsert_response1).to be_success
      end
    end
  end
end
