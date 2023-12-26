# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(Quickbooks::UnincludedLineItemDetailsFactory).to receive(:new).and_return(unincluded_line_item_details_factory)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'name1') }
  let(:revenue_report) { Report.create!(report_service: report_service, template_id: 'revenue_report', slug: 'revenue_report', name: 'Revenue Report') }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_response2) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_info2) { Struct.new(:business).new(business_response2) }
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
  let(:business_api_instance2) do
    instance_double(DocytServerClient::BusinessApi,
                    get_business: business_info2,
                    get_all_business_chart_of_accounts: business_chart_of_accounts_response,
                    get_accounting_classes: accounting_class_response,
                    get_qbo_connection: business_quickbooks_connection_info)
  end
  let(:item_value_factory) { instance_double(ItemValueFactory, generate_batch: true) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:daily_report_data) { create(:report_data, report: report, start_date: '2022-03-01', end_date: '2022-03-01', period_type: ReportData::PERIOD_DAILY) }

  let(:unincluded_line_item_details_factory) { instance_double(Quickbooks::UnincludedLineItemDetailsFactory, create_for_report: true) }

  describe '#update' do
    let(:report_param) do
      {
        report_service_id: report_service.service_id,
        template_id: 'owners_operating_statement',
        name: 'name',
        user_ids: [1],
        accepted_accounting_class_ids: [1],
        accepted_chart_of_account_ids: [1]
      }
    end

    it 'update report' do
      result = described_class.update(report: report, report_params: report_param)
      expect(result).to be_success
    end
  end

  describe '#enqueue_report_update' do
    let(:report_param) do
      {
        report_service_id: report_service.service_id,
        template_id: 'owners_operating_statement',
        name: 'name'
      }
    end

    it 'refreshes report' do
      expect do
        described_class.enqueue_report_update(report: report)
      end.to change { DocytLib.async.event_queue.size }.by(1)
      expect(DocytLib.async.event_queue.events.last.priority).to eq(ReportFactory::MANUAL_UPDATE_PRIORITY)
    end
  end

  describe '#handle_update_error' do
    let(:server_api_error) { DocytServerClient::ApiError.new({ message: 'Internal Server Error', code: 503 }) }

    it 'logs the 500 error with Rollbar' do
      allow(Rollbar).to receive(:error)

      described_class.handle_update_error(report: report, error: server_api_error)
      expect(Rollbar).to have_received(:error).once
    end
  end

  describe '#enqueue_report_datas_update' do
    context 'with daily params' do
      let(:params) do
        {
          start_date: '2022-03-01',
          end_date: '2022-03-01',
          period_type: ReportData::PERIOD_DAILY
        }
      end

      it 'fires event to refresh report' do
        expect do
          described_class.enqueue_report_datas_update(report: report, params: params)
          expect(report.report_datas.first.update_state).to eq(Report::UPDATE_STATE_QUEUED)
        end.to change { DocytLib.async.event_queue.size }.by(1)
      end
    end

    context 'with monthly params' do
      let(:params) do
        {
          start_date: '2022-03-01',
          end_date: '2022-05-31',
          period_type: ReportData::PERIOD_MONTHLY
        }
      end

      it 'fires event to refresh report' do
        expect do
          described_class.enqueue_report_datas_update(report: report, params: params)
          expect(report.report_datas.find_by(start_date: '2022-05-01', end_date: '2022-05-31').update_state).to eq(Report::UPDATE_STATE_QUEUED)
        end.to change { DocytLib.async.event_queue.size }.by(1)
      end
    end
  end
end
