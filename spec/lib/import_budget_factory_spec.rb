# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImportBudgetFactory do
  before do
    stub_request(:get, /.*internal.*by_token*/).to_return(status: 200, body: '{"file": {"id": "77"}}', headers: { 'Content-Type' => 'application/json' })
  end

  let(:secure_user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }

  describe '#create' do
    let(:import_params) do
      {
        file_token: 'test'
      }
    end

    it 'create a import_budget' do
      result = described_class.create(import_params: import_params, secure_user: secure_user, budget: budget)
      expect(result).to be_success
    end
  end
end
