# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::DepartmentReportDatasController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT, name: 'name1') }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:item) do
    item = custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item')
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
    item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1002)
    item
  end

  describe 'GET #by_range' do
    subject(:by_range_response) do
      get :by_range, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        from: '2021-01-01',
        to: '2021-03-31',
        filter: ''
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_range_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_range_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
