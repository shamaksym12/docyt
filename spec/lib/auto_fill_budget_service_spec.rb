# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoFillBudgetService do
  before do
    allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(metrics_service_value_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(Quickbooks::GeneralLedgerImporter).to receive(:new).and_return(general_ledger_importer)
    allow(Quickbooks::GeneralLedgerAnalyzer).to receive(:new).and_return(general_ledger_analyzer)
  end

  let(:metric_value_response) { Struct.new(:value).new(15.0) }
  let(:metrics_service_value_api_instance) { instance_double(MetricsServiceClient::ValueApi, get_metric_value: metric_value_response) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '95', mapped_class_ids: [1, 2, 3])
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '101', mapped_class_ids: [1, 2, 3])
  end
  let(:business_all_chart_of_account_info) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class1, accounting_class2]) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_all_business_chart_of_accounts: business_all_chart_of_account_info,
                    get_accounting_classes: accounting_class_response)
  end
  let(:general_ledger_importer) { instance_double(Quickbooks::GeneralLedgerImporter, general_ledger: common_general_ledger, import: true, fetch_qbo_token: true) }
  let(:general_ledger_analyzer) { instance_double(Quickbooks::GeneralLedgerAnalyzer, analyze: true) }

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:common_general_ledger) do
    ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2021-01-01',
                                              end_date: '2021-01-31')
  end
  let(:standard_metric) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022) }
  let(:budget_item_values) do
    [
      { month: 1, value: 20 },
      { month: 2, value: 20 },
      { month: 3, value: 20 },
      { month: 4, value: 20 },
      { month: 5, value: 20 },
      { month: 6, value: 20 },
      { month: 7, value: 20 },
      { month: 8, value: 20 },
      { month: 9, value: 20 },
      { month: 10, value: 20 },
      { month: 11, value: 20 },
      { month: 12, value: 20 }
    ]
  end
  let(:budget_item1) do
    DraftBudgetItem.create!(
      budget_id: budget.id,
      chart_of_account_id: 1001,
      accounting_class_id: 1,
      budget_item_values: budget_item_values
    )
  end
  let(:budget_item2) do
    DraftBudgetItem.create!(
      budget_id: budget.id,
      standard_metric_id: standard_metric.id,
      chart_of_account_id: nil,
      accounting_class_id: nil,
      budget_item_values: budget_item_values
    )
  end

  describe '#perform' do
    context 'when standard_metric_id is nil' do
      let(:params) do
        {
          business_id: 1,
          year: 2021,
          increase: 1,
          clear: false,
          months: [*1..12],
          budget_item_ids: [budget_item1.id.to_s]
        }
      end

      it 'returns actuals from budget item values' do
        described_class.new(budget: budget, params: params).perform
        expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(220.0)
      end
    end

    context 'when standard_metric_id exist' do
      let(:params) do
        {
          business_id: 1,
          year: 2021,
          increase: 2,
          clear: false,
          months: [*1..12],
          budget_item_ids: [budget_item2.id.to_s]
        }
      end

      it 'returns actuals from metrics-service' do
        standard_metric
        described_class.new(budget: budget, params: params).perform
        expect(budget.draft_budget_items[0].budget_item_values.sum(:value)).to eq(360.0)
      end
    end
  end
end
