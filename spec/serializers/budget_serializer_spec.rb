# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budgets
#
#  id                   :string
#  report_service_id    :integer
#  name                 :string
#  year                 :integer
#  total_amount         :float
#  creator_id           :integer
#  created_at           :datetime
#

require 'rails_helper'

RSpec.describe BudgetSerializer do
  let(:user) { Struct.new(:id).new(1) }
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:budget) { Budget.create!(report_service: report_service, name: 'budget1', year: 2021, updated_at: Time.zone.yesterday) }

  it 'contains budget information in json' do
    decorated_budget = BudgetsDecorator.decorate(budget, context: { users: [user] })
    json_string = described_class.new(decorated_budget).to_json
    result_hash = JSON.parse(json_string)['budget']
    expect(result_hash['report_service_id']).to eq(132)
    expect(result_hash['name']).to eq('budget1')
    expect(result_hash['year']).to eq(2021)
    expect(result_hash['total_amount']).to eq(0.0)
  end
end
