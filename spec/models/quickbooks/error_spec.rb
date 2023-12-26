# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::Error do
  describe '.error_message' do
    subject(:error_message) { described_class.error_message(error: qbo_error) }

    let(:qbo_error_code) { '3000' }
    let(:qbo_error) do
      response = double( # rubocop:disable RSpec/VerifiedDoubles
        parsed: {
          'Fault' => {
            'Error' => [{
              'code' => qbo_error_code,
              'Detail' => 'ERROR'
            }]
          }
        },
        status: 429
      ).as_null_object
      OAuth2::Error.new(response)
    end

    context 'with AUTHORIZATION_FAILED error' do
      let(:qbo_error_code) { '3200' }

      it 'returns "QuickBooks is disconnected."' do
        expect(error_message).to eq('QuickBooks is disconnected.')
      end
    end

    context 'with INTERNAL_SERVER_ERROR error' do
      let(:qbo_error_code) { '3100' }

      it 'returns "Currently Quickbooks Online is not available. Try to update the report again later."' do
        expect(error_message).to eq('Currently Quickbooks Online is not available. Try to update the report again later.')
      end
    end

    context 'with THROTTLING_ERROR error' do
      let(:qbo_error_code) { '3001' }

      it 'returns "Docyt has been making too many requests to Quickbooks. Try to update the report again later."' do
        expect(error_message).to eq('Docyt has been making too many requests to Quickbooks. Try to update the report again later.')
      end
    end

    context 'with other errors' do
      it 'returns "Unknown Error"' do
        expect(error_message).to eq('Unknown Error')
      end
    end
  end
end
