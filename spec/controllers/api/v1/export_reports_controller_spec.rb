# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ExportReportsController do
  before do
    allow_any_instance_of(ApplicationController).to receive(:secure_user).and_return(secure_user) # rubocop:disable RSpec/AnyInstance
  end

  let(:secure_user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'departmental_report', slug: 'departmental_report', name: 'name1') }
  let(:multi_business_report) do
    MultiBusinessReport.create!(report_ids: [report.id], multi_business_report_service_id: 111,
                                template_id: 'departmental_report', name: 'name1')
  end

  describe 'POST #create with EXPORT_TYPE_REPORT' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        export_type: ExportReport::EXPORT_TYPE_REPORT,
        start_date: '2022-12-01',
        end_date: '2022-12-31',
        filter: {
          accounting_class_id: '',
          is_zero_rows_hidden: true
        },
        report_id: report.id.to_s
      }
    end

    context 'with permission' do
      it 'returns 201 response' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #create with EXPORT_TYPE_MULTI_ENTITY_REPORT' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        export_type: ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT,
        start_date: '2022-12-01',
        end_date: '2022-12-31',
        filter: { is_zero_rows_hidden: false },
        multi_business_report_id: multi_business_report.id.to_s
      }
    end

    context 'with permission' do
      it 'returns 201 response' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_multi_business_report).and_return(true) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_multi_business_report).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #create with EXPORT_TYPE_CONSOLIDATED_REPORT' do
    subject(:create_response) do
      post :create, params: params
    end

    let(:params) do
      {
        export_type: ExportReport::EXPORT_TYPE_CONSOLIDATED_REPORT,
        start_date: '2022-12-01',
        end_date: '2022-12-31',
        filter: {},
        report_service_id: report_service.service_id
      }
    end

    context 'with permission' do
      it 'returns 201 response' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_service_access).and_return(true) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:created)
      end
    end

    context 'without permission' do
      it 'returns 403 response when the user has no permission' do
        allow_any_instance_of(ApplicationController).to receive(:ensure_report_service_access).and_raise(DocytLib::Helpers::ControllerHelpers::NoPermissionException) # rubocop:disable RSpec/AnyInstance
        create_response
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
