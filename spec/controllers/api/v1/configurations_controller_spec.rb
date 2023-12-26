# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ConfigurationsController do
  describe 'GET #index' do
    let(:json_response) { JSON.parse(response.body, symbolize_names: true) }

    context 'when requesting all configurations' do
      before { get :index }

      it 'returns a 200 response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all configurations' do
        expect(json_response[:configurations].length).to eq(3)
      end
    end
  end
end
