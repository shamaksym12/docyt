# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDependencies::Mapping, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
  let(:child_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: parent_item.id.to_s) }
  let(:item_account) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:report_data) do
    create(:report_data, report: report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY)
  end

  describe '#calculate_digest' do
    it 'returns calculated digest' do
      item_account
      report_data.recalc_digest!
      expect(described_class.new(report_data)).not_to have_changed
      item_account.update(chart_of_account_id: 2)
      expect(described_class.new(report_data)).to have_changed
    end
  end
end
