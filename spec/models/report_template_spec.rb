# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportTemplate do
  let(:template) { described_class.from_file('spec/fixtures/templates/revenue_report.json') }

  it 'loads all production templates correctly' do
    TemplatesQuery.all_template_files.each do |f|
      expect { described_class.from_file(f) }.not_to raise_error
    end
  end

  describe '#columns' do
    it 'returns columns' do
      columns = template.columns
      expect(columns.length).to eq(7)

      first_column = columns[0]
      expect(first_column).to be_an_instance_of(ReportTemplate::Column)
      expect(first_column).to have_attributes(type: 'actual', range: 'current_period', year: 'current')
    end
  end

  describe '#items' do
    it 'returns items' do
      items = template.items
      expect(items.length).to eq(37)

      first_item = items[0]
      expect(first_item).to be_an_instance_of(ReportTemplate::Item)
      expect(first_item).to have_attributes(id: 'metrics', name: 'Metrics')
    end
  end

  describe '.find_by' do
    it 'returns template for P&L report' do
      template = described_class.find_by(template_id: ProfitAndLossReport::PROFITANDLOSS_REPORT_TEMPLATE_ID)
      expect(template).to be_present
    end

    it 'returns template for other report' do
      template = described_class.find_by(template_id: 'revenue_report')
      expect(template).to be_present
    end
  end
end
