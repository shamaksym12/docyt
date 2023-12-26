# frozen_string_literal: true

require 'rails_helper'

module Api
  module V1
    module Quickbooks
      RSpec.describe LineItemDetailsController do
        before do
          allow_any_instance_of(described_class).to receive(:ensure_report_access).and_return(true) # rubocop:disable RSpec/AnyInstance
          allow(::Quickbooks::LineItemDetailsQuery).to receive(:new).and_return(line_item_details_query)
        end

        let(:business_id) { Faker::Number.number(digits: 10) }
        let(:service_id) { Faker::Number.number(digits: 10) }
        let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
        let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
        let(:line_item_detail) { ::Quickbooks::LineItemDetail.new(amount: 10.0) }
        let(:line_item_details_query) do
          instance_double(::Quickbooks::LineItemDetailsQuery, by_period: [line_item_detail])
        end
        let(:params) do
          {
            report_id: custom_report._id.to_s,
            from: '2021-03-01',
            to: '2021-03-31',
            chart_of_account_id: nil,
            accounting_class_id: nil
          }
        end

        describe 'GET #by_period' do
          subject(:by_period_response) do
            get :by_period, params: params
          end

          context 'with permission' do
            it 'returns 200 response' do
              by_period_response
              expect(response).to have_http_status(:ok)
            end
          end
        end
      end
    end
  end
end
