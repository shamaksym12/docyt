# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::StandardMetricsController do
  let(:standard_metric) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Availabel Rooms', code: 'rooms_available') }

  describe 'GET #index' do
    subject(:index_response) do
      get :index, params: {}
    end

    context 'with permission' do
      it 'returns 200 response' do
        index_response
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
