# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::UnincludedLineItemDetailsFactory do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1',
                    acc_type: 'Expense', acc_type_name: 'Expense', sub_type: 'sub1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '102', display_name: 'name2',
                    acc_type: 'Expense', acc_type_name: 'Expense', sub_type: 'sub2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '103', display_name: 'name3',
                    acc_type: 'Expense', acc_type_name: 'Expense', sub_type: 'sub3')
  end
  let(:business_chart_of_account4) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1004, qbo_id: '104', display_name: 'name4',
                    acc_type: 'Fixed Asset', acc_type_name: 'Fixed Asset', sub_type: 'sub4')
  end
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class3) { instance_double(DocytServerClient::AccountingClass, id: 3, business_id: 105, external_id: '2') }

  describe '#create_for_report without start_date' do
    subject(:create_for_report) do
      described_class.create_for_report(report: report,
                                        start_date: '2022-01-01'.to_date,
                                        end_date: '2022-12-31'.to_date,
                                        all_business_chart_of_accounts: [business_chart_of_account1, business_chart_of_account2,
                                                                         business_chart_of_account3, business_chart_of_account4],
                                        accounting_classes: [accounting_class1, accounting_class2, accounting_class3])
    end

    context 'when unincluded transaction is exist' do
      before do
        report.update!(accepted_chart_of_account_ids: [1001, 1002, 1004],
                       accepted_accounting_class_ids: [0, 1, 2, 3])
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-01', amount: 10.0, chart_of_account_qbo_id: '103', accounting_class_qbo_id: '2'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-02', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-03', amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-04', amount: 10.0, chart_of_account_qbo_id: '103', accounting_class_qbo_id: '4'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '4'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-06', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '2'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-06', amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: nil
        )
        common_general_ledger.save!
        allow(report).to receive(:all_item_accounts).and_return(report_item_accounts)
      end

      let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
      let(:common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31')
      end
      let(:report_item_accounts) do
        [
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1001, 2),
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1002, nil),
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1003, nil)
        ]
      end

      it 'creates unincluded_line_item_details' do
        create_for_report
        report.reload
        expect(report.unincluded_line_item_details.count).to eq(3)
        expect(report.unincluded_line_item_details[0].transaction_date).to eq('2022-08-05')
        expect(report.unincluded_line_item_details[1].transaction_date).to eq('2022-08-06')
        expect(report.unincluded_line_item_details[2].transaction_date).to eq('2022-08-06')
      end
    end

    context 'when unincluded transaction is not exist' do
      before do
        allow(report).to receive(:all_item_accounts).and_return(report_item_accounts)
      end

      let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
      let(:report_item_accounts) do
        [
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1001, 2),
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1001, nil)
        ]
      end

      it 'creates unincluded_line_item_details' do
        create_for_report
        report.reload
        expect(report.unincluded_line_item_details.count).to eq(0)
      end
    end
  end

  describe '#create_for_report with start_date' do
    subject(:create_for_report) do
      described_class.create_for_report(
        report: report, start_date: '2022-08-01',
        end_date: '2022-08-31',
        all_business_chart_of_accounts: [business_chart_of_account1, business_chart_of_account2,
                                         business_chart_of_account3, business_chart_of_account4],
        accounting_classes: [accounting_class1, accounting_class2, accounting_class3]
      )
    end

    context 'when unincluded transaction is exist' do
      before do
        report.update!(accepted_chart_of_account_ids: [1001, 1002, 1004],
                       accepted_accounting_class_ids: [1])
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-01', amount: 10.0, chart_of_account_qbo_id: '103', accounting_class_qbo_id: '2'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-02', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '1'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-03', amount: 10.0, chart_of_account_qbo_id: '102', accounting_class_qbo_id: nil
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-04', amount: 10.0, chart_of_account_qbo_id: '103', accounting_class_qbo_id: '4'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-05', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '4'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-06', amount: 10.0, chart_of_account_qbo_id: '101', accounting_class_qbo_id: '2'
        )
        common_general_ledger.line_item_details << Quickbooks::LineItemDetail.new(
          transaction_date: '2022-08-06', amount: 10.0, chart_of_account_qbo_id: '104', accounting_class_qbo_id: nil
        )
        common_general_ledger.save!
        allow(report).to receive(:all_item_accounts).and_return(report_item_accounts)
      end

      let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
      let(:common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31')
      end
      let(:report_item_accounts) do
        [
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1001, 2),
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1002, nil),
          Struct.new(:chart_of_account_id, :accounting_class_id).new(1003, nil)
        ]
      end

      it 'creates unincluded_line_item_details' do
        create_for_report
        report.reload
        expect(report.unincluded_line_item_details.count).to eq(1)
        expect(report.unincluded_line_item_details[0].transaction_date).to eq('2022-08-05')
      end
    end
  end
end
