# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::LineItemDetailsQuery do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_api_instance)
  end

  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1', acc_type: 'Expense')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '102', display_name: 'name2', acc_type: 'Bank')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '103', display_name: 'name3', acc_type: 'Expense')
  end
  let(:business_chart_of_account4) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1004, qbo_id: '104', display_name: 'name4', acc_type: 'Expense')
  end
  let(:business_chart_of_account5) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1005, qbo_id: '105', display_name: 'name5', acc_type: 'Expense')
  end
  let(:business_chart_of_accounts_response) do
    Struct.new(:business_chart_of_accounts)
          .new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3, business_chart_of_account4, business_chart_of_account5])
  end
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2]) }
  let(:business_api_instance) do
    instance_double(
      DocytServerClient::BusinessApi,
      get_all_business_chart_of_accounts: business_chart_of_accounts_response,
      get_accounting_classes: accounting_class_response
    )
  end
  let(:report_api_instance) do
    instance_double(
      DocytServerClient::ReportServiceApi,
      get_account_value_links: []
    )
  end
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:start_date) { '2022-08-01' }
  let(:end_date) { '2022-08-31' }

  describe '#by_period without total' do
    subject(:line_item_details_by_period) { described_class.new(report: report, item: item, params: params).by_period(start_date: start_date, end_date: end_date) }

    before do
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-01', amount: 10.0, chart_of_account_qbo_id: '105', accounting_class_qbo_id: '2', qbo_id: '141'
      )
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-02', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1', qbo_id: '142'
      )
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-03', amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil, qbo_id: '143'
      )
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-04', amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: '4', transaction_type: 'Bill Payment (Check)', qbo_id: '149'
      )
      general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
        transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil, transaction_type: 'Bill Payment (Check)', qbo_id: '150'
      )
      general_ledger.save!
    end

    let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item') }
    let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

    context 'without chart_of_account_id and accounting_class_id' do
      let(:params) { {} }

      it 'contains 5 line_item_details' do
        expect(line_item_details_by_period.length).to eq(5)
      end
    end

    context 'with chart_of_account_id and accounting_class_id' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item details' do
        expect(line_item_details_by_period.length).to eq(1)
      end
    end

    context 'with chart_of_account_id' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'does not check accounting_class_id' do
        report.update!(accounting_class_check_disabled: true)
        expect(line_item_details_by_period.length).to eq(2)
      end
    end

    context 'with departmental report item' do
      let(:params) { {} }
      let(:report) { Report.create!(report_service: report_service, template_id: 'departmental_report', slug: Report::DEPARTMENT_REPORT, name: 'name1') }
      let(:item) do
        report.items.create!(name: 'item', order: 1, identifier: 'item',
                             type_config: {
                               'name' => 'quickbooks_ledger',
                               'general_ledger_options' => {
                                 'only_classes' => ['1'],
                                 'include_account_types' => [
                                   'Expense',
                                   'Cost Of Goods Sold',
                                   'Other Expense'
                                 ]
                               }
                             })
      end

      it 'contains 1 expense line_item_details' do
        expect(line_item_details_by_period.length).to eq(1)
      end
    end

    context 'with vendor report item' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item details from bank_general_ledger' do
        report.update(template_id: Report::VENDOR_REPORT)
        item.type_config = {}
        item.type_config[Item::CALCULATION_TYPE_CONFIG] = Item::GENERAL_LEDGER_CALCULATION_TYPE
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(1)
        expect(line_item_details[0].qbo_id).to eq('150')
      end
    end

    context 'with include General Ledger Options' do
      let(:params) { {} }

      it 'only contains 1 line item details' do
        item.type_config = {
          'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
          'general_ledger_options' => {
            'include_account_types' => ['Bank', 'Accounts Payable']
          }
        }
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(1)
        expect(line_item_details[0].chart_of_account_qbo_id).to eq(business_chart_of_account2.qbo_id)
      end
    end

    context 'with include Sub General Ledger Options' do
      let(:params) { {} }

      it 'only contains line item details' do
        item.type_config = {
          'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
          'general_ledger_options' => {
            'include_subledger_account_types' => ['Bank', 'Accounts Payable']
          }
        }
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(1)
        expect(line_item_details[0].chart_of_account_qbo_id).to eq(business_chart_of_account2.qbo_id)
      end
    end

    context 'with exclude Sub General Ledger Options' do
      let(:params) { {} }

      it 'only contains line item details' do
        item.type_config = {
          'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
          'general_ledger_options' => {
            'exclude_subledger_account_types' => ['Bank', 'Accounts Payable']
          }
        }
        line_item_details = line_item_details_by_period
        expect(line_item_details.length).to eq(4)
        expect(line_item_details[0].id).to eq(general_ledger.line_item_details.first.id)
      end
    end

    context 'with amount_type set to debit' do
      before do
        general_ledger.line_item_details.create!(transaction_type: 'Invoice', qbo_id: '149', amount: 10.0)
        general_ledger.line_item_details.create!(transaction_type: 'Payment', qbo_id: '149', amount: -10.0)
        general_ledger.line_item_details.create!(transaction_type: 'Payment', qbo_id: '149', amount: -10.0)
      end

      let(:params) { {} }

      it 'only contains line item details with debit amounts' do
        item.type_config = {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
          'general_ledger_options' => {
            'amount_type' => Item::AMOUNT_TYPE_DEBIT
          }
        }
        line_item_details = line_item_details_by_period

        expect(line_item_details.length).to eq(6)
        expect(line_item_details[0].amount).to be_positive
      end
    end

    context 'with amount_type set to credit' do
      before do
        general_ledger.line_item_details.create!(transaction_type: 'Payment', qbo_id: '149', amount: -10.0)
        general_ledger.line_item_details.create!(transaction_type: 'Payment', qbo_id: '149', amount: -10.0)
      end

      let(:params) { {} }

      it 'only contains line item details with credit amounts' do
        item.type_config = {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
          'general_ledger_options' => {
            'amount_type' => Item::AMOUNT_TYPE_CREDIT
          }
        }
        line_item_details = line_item_details_by_period

        expect(line_item_details.length).to eq(2)
        expect(line_item_details[0].amount).to be_negative
      end
    end
  end

  describe '#by_period with total' do
    subject(:line_item_details_by_period) do
      described_class.new(report: report, item: item, params: params).by_period(
        start_date: start_date, end_date: end_date, include_total: true
      )
    end

    context 'without chart_of_account_id and accounting_class_id' do
      let(:params) { {} }
      let(:item) { report.items.create!(name: 'item', order: 1, identifier: 'item', type_config: { 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE }) }
      let(:general_ledger) { Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

      it 'contains 2 line_item_details' do
        expect(line_item_details_by_period.length).to eq(2)
      end
    end

    context 'with chart_of_account_id and accounting_class_id and balance_sheet type name' do
      before do
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-01',
                                                                           amount: 10.0, chart_of_account_qbo_id: '105', accounting_class_qbo_id: '2')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-02',
                                                                           amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-03',
                                                                           amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil)
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-08-04',
                                                                           amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: '4')
        general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: nil,
          transaction_type: 'Bill Payment (Check)', qbo_id: '150'
        )
        general_ledger.save!

        previous_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(transaction_date: '2022-07-02',
                                                                                    amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1')
        previous_general_ledger.save!
      end

      let(:params) { { chart_of_account_id: 1001 } }
      let(:item) do
        report.items.create!(name: 'item', order: 1, identifier: 'item',
                             type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE })
      end
      let(:previous_general_ledger) { Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2022-07-01', end_date: '2022-07-31') }
      let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

      it 'only contains 1 line item details' do
        expect(line_item_details_by_period.length).to eq(3)
      end
    end
  end
end
