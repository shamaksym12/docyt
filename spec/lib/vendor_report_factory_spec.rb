# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VendorReportFactory do
  before do
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
  end

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'vendor_report', slug: 'vendor_report', name: 'name1') }
  let(:bookkeeping_start_date) { Time.zone.today - 1.month }
  let(:business_response) do
    instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: bookkeeping_start_date)
  end
  let(:business_info) { Struct.new(:business).new(business_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_vendor1) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 1, business_id: business_id, vendor_id: 1001, qbo_id: '60', name: 'vendor_name1')
  end
  let(:business_vendor2) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 2, business_id: business_id, vendor_id: 1002, qbo_id: '95', name: 'name2')
  end
  let(:business_vendor3) do
    instance_double(DocytServerClient::BusinessVendor,
                    id: 2, business_id: business_id, vendor_id: 1002, qbo_id: nil, name: 'name2')
  end
  let(:business_vendors) { [business_vendor1, business_vendor2, business_vendor3] }
  let(:business_vendors_response) { Struct.new(:business_vendors).new(business_vendors) }
  let(:accounting_class_response) { Struct.new(:accounting_classes).new([]) }
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

  describe '#sync_report_infos' do
    it 'syncs and creates items for vendor report' do
      described_class.sync_report_infos(report: report)
      expect(report.template_id).to eq(Report::VENDOR_REPORT)
      expect(report.items.length).to eq(3)
      expect(report.items[1].identifier).to eq('60')
    end

    it 'syncs and updates items for vendor report' do
      report.items.create!(name: 'vendor_total_expenses', order: 1, identifier: 'vendor_total_expenses')
      report.items.create!(name: '60', order: 2, identifier: '60')
      report.items.create!(name: '95', order: 3, identifier: '95')
      described_class.sync_report_infos(report: report)
      expect(report.template_id).to eq(Report::VENDOR_REPORT)
      expect(report.items.length).to eq(3)
    end
  end
end
