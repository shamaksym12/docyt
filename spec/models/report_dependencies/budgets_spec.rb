# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Budgets, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:budget) { Budget.create!(report_service: report_service, name: 'budget1', year: 2021, updated_at: Time.zone.yesterday) }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY, budget_ids: [budget.id])
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      report_data.recalc_digest!
      expect(described_class.new(report_data)).not_to have_changed
      budget.update(updated_at: Time.zone.now)
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
