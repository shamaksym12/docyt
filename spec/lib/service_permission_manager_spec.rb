# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ServicePermissionManager, rbac: true do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
  end

  let(:metric_start_date) { Time.zone.today - 10.days }
  let(:business_metric_response) do
    instance_double(MetricsServiceClient::BusinessMetricResponse,
                    id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                    data_type: 'currency', start_date: metric_start_date, input_data_mode: 'Integration')
  end
  let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
  let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }
  let(:user) { Struct.new(:id).new(1) }
  let(:service) { described_class.new(user: user) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }

  describe '#can_access_multi_business_service!' do
    let(:multi_business_service) { Struct.new(:id, :consumer_id).new(101, 105) }
    let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_service) }

    it 'raises error when no permission provided' do
      allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
      expect(service.can_access_multi_business_service(multi_business_report_service_id: 102).to_s).to eq('false')
    end

    it 'not raise error for MultibusinessReportService exists' do
      allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
      expect(service.can_access_multi_business_service(multi_business_report_service_id: 101).to_s).to eq('true')
    end
  end

  describe '#can_access_advanced_report' do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:custom_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: 'owners_operating_statement', name: 'name1' }, current_user: user).report
    end

    it 'returns true if user can access the report' do
      expect(service.can_access_advanced_report(report: custom_report).to_s).to eq('true')
    end
  end
end
