# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DepartmentalReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT, name: 'Departmental Report') }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1', acc_type: 'Expense')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2', acc_type: 'Expense')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3', acc_type: 'Expense')
  end
  let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:report_dependency) { instance_double(ReportDependencies::Base, has_changed?: false) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end

  describe '#sync_report_infos' do
    subject(:sync_report_infos) { described_class.sync_report_infos(report: report) }

    it 'generates items for departmental report' do
      sync_report_infos
      expect(report.template_id).to eq(Report::DEPARTMENT_REPORT)
      expect(report.items[0].identifier).to eq(described_class::ITEM_REVENUE)
      expect(report.items.length).to eq(18)
    end

    it 'does not create existing item, only update items' do
      sync_report_infos
      before_revenue_child_item = report.items.find_by(identifier: "#{described_class::ITEM_REVENUE}_#{accounting_class1.external_id}")
      sync_report_infos
      after_revenue_child_item = report.items.find_by(identifier: "#{described_class::ITEM_REVENUE}_#{accounting_class1.external_id}")
      expect(report.template_id).to eq(Report::DEPARTMENT_REPORT)
      expect(report.items[0].identifier).to eq(described_class::ITEM_REVENUE)
      expect(after_revenue_child_item.id).to eq(before_revenue_child_item.id)
    end
  end
end
