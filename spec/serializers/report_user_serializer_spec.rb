# frozen_string_literal: true

# == Mongoid Information
#
# Document name: report_user
#
#  id                   :string
#  user_id              :integer
#

require 'rails_helper'

RSpec.describe ReportUserSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_user) { report.report_users.create!(user_id: 111) }

  it 'contains user information in json' do
    json_string = described_class.new(report_user).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['report_user']['id']).not_to be_nil
    expect(result_hash['report_user']['user_id']).to eq(report_user.user_id)
  end
end
