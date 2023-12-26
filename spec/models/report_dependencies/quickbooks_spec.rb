# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Quickbooks, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'vendor_report', slug: 'vendor_report', name: 'name1') }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end
  let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:line_item_detail) do
    general_ledger.line_item_details.create!(transaction_date: '2021-03-02', amount: 10, qbo_id: '1')
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      line_item_detail
      report_data.recalc_digest!
      expect(described_class.new(report_data)).not_to have_changed
      line_item_detail.update(amount: 5)
      general_ledger.set_digest
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
