# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::ReportTemplate, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end

  describe '#calculate_digest' do
    it 'returns calculated digest for general report' do
      report_data.recalc_digest!
      expect(described_class.new(report_data)).not_to have_changed
      report.update(template_id: 'operators_operating_statement')
      expect(described_class.new(report_data)).to have_changed
    end

    it 'returns calculated digest for P&L report' do
      report_data.recalc_digest!
      report.update(template_id: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID)
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
