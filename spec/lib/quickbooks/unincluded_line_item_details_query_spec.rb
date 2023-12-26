# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::UnincludedLineItemDetailsQuery do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::ReportServiceApi).to receive(:new).and_return(report_api_instance)
  end

  let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }

  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: 105, chart_of_account_id: 1002, qbo_id: '102', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: 105, chart_of_account_id: 1003, qbo_id: '103', display_name: 'name3')
  end
  let(:business_chart_of_accounts_response) { OpenStruct.new(business_chart_of_accounts: [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3]) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4') }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: 105, external_id: '1') }
  let(:accounting_class_response) { OpenStruct.new(accounting_classes: [accounting_class1, accounting_class2]) }
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

  describe '#by_period' do
    subject(:line_item_details_by_period) { described_class.new(report: report, params: params).by_period(start_date: start_date, end_date: end_date) }

    before do
      line_item_detail1
      line_item_detail2
      line_item_detail3
      line_item_detail4
      line_item_detail5
    end

    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
    let(:start_date) { '2022-08-01' }
    let(:end_date) { '2022-08-31' }

    let(:line_item_detail1) { create(:unincluded_line_item_detail, report: report, transaction_date: '2022-07-10') }
    let(:line_item_detail2) { create(:unincluded_line_item_detail, report: report, transaction_date: '2022-08-11') }
    let(:line_item_detail3) { create(:unincluded_line_item_detail, report: report, transaction_date: '2022-08-15') }
    let(:line_item_detail4) { create(:unincluded_line_item_detail, report: report, transaction_date: '2022-08-31') }
    let(:line_item_detail5) { create(:unincluded_line_item_detail, report: report, transaction_date: '2022-09-11') }

    context 'without chart_of_account_id and accounting_class_id' do
      let(:params) { {} }

      it 'contains 3 line_item_details' do
        expect(line_item_details_by_period.length).to eq(3)
      end
    end

    context 'with chart_of_account_id and accounting_class_id' do
      let(:params) { { chart_of_account_id: 1001 } }

      it 'only contains 1 line item detail' do
        create(:unincluded_line_item_detail, report: report, transaction_date: '2022-08-15', chart_of_account_qbo_id: '101')
        expect(line_item_details_by_period.length).to eq(1)
      end
    end
  end
end
