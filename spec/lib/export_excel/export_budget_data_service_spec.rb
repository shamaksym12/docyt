# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe ExportBudgetDataService do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(Axlsx::Worksheet).to receive(:new).and_return(work_sheet_instance)
    end

    let(:report_service) { ReportService.create!(service_id: 132, business_id: 207) }
    let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }
    let(:business_chart_of_account1) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 1, business_id: 105, chart_of_account_id: 1001, display_name: 'test', acc_type_name: 'test')
    end
    let(:business_chart_of_account2) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 2, business_id: 105, chart_of_account_id: 1002, display_name: 'test', acc_type_name: 'test')
    end
    let(:business_chart_of_account3) do
      instance_double(DocytServerClient::BusinessChartOfAccount, id: 3, business_id: 105, chart_of_account_id: 1003, display_name: 'test', acc_type_name: 'test')
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
    let(:sheet_row) { Struct.new(:outline_level, :hidden).new(0, false) }
    let(:sheet_view) { Struct.new(:view).new({ show_outline_symbols: false }) }
    let(:work_sheet_instance) { instance_double(Axlsx::Worksheet, add_row: sheet_row, sheet_view: sheet_view) }

    describe '#call' do
      it 'creates a new budget export' do
        result = described_class.call(budget: budget, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date,
                                      filter: { account_type: 'profit_loss', accounting_class_id: 12, chart_of_account_display_name: 'test', hide_blank: true })
        expect(result).to be_success
        expect(work_sheet_instance).to have_received(:add_row).exactly(6)
      end
    end
  end
end
