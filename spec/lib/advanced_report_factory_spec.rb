# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdvancedReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'name1') }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_account1) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
  end
  let(:business_chart_of_account2) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '95', display_name: 'name2')
  end
  let(:business_chart_of_account3) do
    instance_double(DocytServerClient::BusinessChartOfAccount,
                    id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '101', display_name: 'name3')
  end
  let(:business_vendor) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 3, business_id: business_id, vendor_id: 1003, qbo_id: '101', name: 'name')
  end
  let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3] }
  let(:business_vendors) { [business_vendor] }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new(business_chart_of_accounts) }
  let(:business_vendors_response) { Struct.new(:business_vendors).new(business_vendors) }
  let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'class01', parent_external_id: nil) }
  let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'class02', parent_external_id: nil) }
  let(:sub_class) { instance_double(DocytServerClient::AccountingClass, id: 2, name: 'sub_class', business_id: business_id, external_id: '5', parent_external_id: '1') }
  let(:accounting_classes) { [accounting_class1, accounting_class2, sub_class] }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new(accounting_classes) }
  let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
  let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
  let(:business_api_instance) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_all_business_vendors: business_vendors_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:item_value_factory) { instance_double(ItemValueFactory, generate_batch: true) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }

  describe '#create' do
    subject(:create_report) { described_class.create(report_service: report_service, report_params: report_param.to_h, current_user: user) }

    let(:report_param) do
      {
        template_id: 'food_beverage_schedule_two',
        name: 'name'
      }
    end

    it 'creates a new report with items and columns' do
      expect(create_report).to be_success
      expect(create_report.report).not_to be_nil
    end

    it 'refreshes report' do
      allow(Report).to receive(:new).and_return(report)
      create_report
    end

    it 'creates a new department report' do
      report_param[:template_id] = Report::DEPARTMENT_REPORT
      result = create_report
      expect(result).to be_success
      expect(result.report).not_to be_nil
    end

    it 'creates a new vendor report' do
      report_param[:template_id] = Report::VENDOR_REPORT
      result = create_report
      expect(result).to be_success
      expect(result.report).not_to be_nil
    end

    it 'creates multiple reports for department category' do
      report_param[:template_id] = 'schedule_6'
      described_class.create(report_service: report_service, report_params: report_param.to_h, current_user: user)
      described_class.create(report_service: report_service, report_params: report_param.to_h, current_user: user)
      expect(Report.where(template_id: 'schedule_6').count).to eq(2)
    end

    it 'will raise an error when tries to create existing and non-departmental report' do
      report_param[:template_id] = 'operators_operating_statement'
      described_class.create(report_service: report_service, report_params: report_param.to_h, current_user: user)
      result = described_class.create(report_service: report_service, report_params: report_param.to_h, current_user: user)
      expect(result.errors[0]).to eq(I18n.t('Report is already created.'))
    end
  end
end
