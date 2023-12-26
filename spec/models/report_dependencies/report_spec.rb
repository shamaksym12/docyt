# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Report, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) do
    Report.create!(
      report_service: report_service,
      template_id: 'owners_operating_statement',
      slug: 'owners_operating_statement',
      name: 'name1',
      accepted_accounting_class_ids: [0, 1],
      accepted_chart_of_account_ids: [0, 1]
    )
  end
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      report_data.recalc_digest!
      report.update(accepted_accounting_class_ids: [2, 3])
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
