# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ItemValuesController do
  before do
    item_value
    allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:from) { '2021-01-01' }
  let(:to) { '2021-02-28' }
  let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY) }
  let(:item_identifier) { Faker::Lorem.characters(12) }
  let(:item) { custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: item_identifier) }
  let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value) { report_data.item_values.create!(item_id: item._id.to_s, column_id: column._id.to_s, value: 3.0) }

  describe 'GET #show' do
    subject(:show_response) do
      get :show, params: params
    end

    let(:params) do
      {
        report_data_id: report_data._id,
        id: id
      }
    end

    context 'with valid params' do
      let(:id) { item_value._id }

      it 'returns 200 response when the user has permission' do
        show_response
        expect(response).to have_http_status(:ok)
      end

      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        show_response
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid params' do
      let(:id) { Faker::Number.number(digits: 10) }

      it 'returns 422 response' do
        show_response
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #by_range' do
    subject(:by_range_response) do
      get :by_range, params: params
    end

    let(:params) do
      {
        report_id: custom_report._id,
        to: to,
        from: from,
        item_identifier: item.identifier
      }
    end

    context 'with permission' do
      it 'returns 200 response' do
        by_range_response
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without permission' do
      it 'returns 403 response' do
        allow_any_instance_of(described_class).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        by_range_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
