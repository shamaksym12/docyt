# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemFactory do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }

  describe '#report_items' do
    subject(:report_items) do
      described_class.report_items(report: report).items
    end

    before do
      items = JSON.parse(file_fixture('report_items.json').read)
      report.update!(items: items)
    end

    context 'when contains stats items' do
      it 'returns sorted items' do
        expect(report_items.last.type_config['name']).to eq(Item::TYPE_STATS)
      end
    end
  end
end
