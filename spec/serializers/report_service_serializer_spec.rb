# frozen_string_literal: true

# == Mongoid Information
#
# Document name: report_service
#
#  id                   :string
#  report_service_id    :integer
#  template_id          :string
#  name                 :string
#  default_budget_id    :string
#

require 'rails_helper'

RSpec.describe ReportServiceSerializer do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:budget) { Budget.create!(report_service: report_service, name: 'name', year: 2022, total_amount: 123.4) }
  let(:budget_id) { budget._id.to_s }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:pl_report) do
    ProfitAndLossReport.create!(report_service: report_service, template_id: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID,
                                slug: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID, name: 'name1')
  end
  let(:balance_sheet_report) do
    BalanceSheetReport.create!(report_service: report_service, template_id: BalanceSheetReport::BALANCE_SHEET_REPORT,
                               slug: BalanceSheetReport::BALANCE_SHEET_REPORT, name: 'Balance Sheet')
  end

  it 'contains report service information in json' do # rubocop:disable RSpec/MultipleExpectations
    pl_report
    balance_sheet_report
    report_service.update!(default_budget_id: budget_id)
    json_string = described_class.new(report_service).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['report_service']['business_id']).to eq(business_id)
    expect(result_hash['report_service']['service_id']).to eq(service_id)
    expect(result_hash['report_service']['pl_report_id']).to eq(pl_report._id.to_s)
    expect(result_hash['report_service']['balance_sheet_report_id']).to eq(balance_sheet_report._id.to_s)
    expect(result_hash['report_service']['default_budget_id']).to eq(budget_id)
  end
end
