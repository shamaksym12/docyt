# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportBudgetFactory do
  let(:secure_user) { Struct.new(:id).new(1) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }

  describe '#create' do
    let(:export_params) do
      {
        start_date: '2022-12-01',
        end_date: '2022-12-31',
        filter: {
          account_type: 'profit_loss',
          accounting_class_id: 12,
          chart_of_account_display_name: 'test',
          hide_blank: true
        }
      }
    end

    it 'create a export_budget' do
      result = described_class.create(export_params: export_params, secure_user: secure_user, budget: budget)
      expect(result).to be_success
    end
  end
end
