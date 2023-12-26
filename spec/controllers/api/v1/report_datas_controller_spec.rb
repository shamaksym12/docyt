# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ReportDatasController do
  before do
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:daily_report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-01', period_type: ReportData::PERIOD_DAILY) }
  let(:item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value) { report_data.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0) }

  describe 'GET #by_range' do
    subject(:by_range_response) do
      get :by_range, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        from: '2021-01-01',
        to: '2021-03-31'
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

  describe 'POST #update_data' do
    subject(:update_data_response) do
      post :update_data, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        start_date: daily_report_data.start_date,
        end_date: daily_report_data.end_date,
        period_type: ReportData::PERIOD_DAILY
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        update_data_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        update_data_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
