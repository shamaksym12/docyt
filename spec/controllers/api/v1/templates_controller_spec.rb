# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TemplatesController do
  describe 'GET #index' do
    let(:json_response) { JSON.parse(response.body, symbolize_names: true) }

    context 'when requesting templates for a specific industry' do
      before { get :index, params: { standard_category_id: 9 } }

      it 'returns a 200 response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns templates for the specific industry' do
        expect(json_response[:templates].length).to be > 10
      end
    end

    context 'when requesting templates for an unspecified industry' do
      before { get :index, params: { standard_category_id: nil } }

      it 'returns a 200 response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns templates for an unspecified industry' do
        expect(json_response[:templates].length).to eq(3)
      end
    end
  end

  describe 'GET #all_templates' do
    subject(:all_templates_response) do
      get :all_templates, params: params
    end

    let(:params) do
      {
        standard_category_id: 9
      }
    end

    it 'returns 200 response and all templates' do
      all_templates_response
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body, symbolize_names: true)
      expect(json_response[:templates].length).to be > 10
    end
  end
end
