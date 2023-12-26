# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  RSpec.describe CachingReportDatasService do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31') }
    let(:caching_report_datas_service) { described_class.new(report_service) }

    describe '#get' do
      let(:start_date) { '2021-07-01' }
      let(:end_date) { '2021-07-31' }

      it 'caches ReportData' do
        report_data
        allow(ReportData).to receive(:find_by).and_call_original
        fetched_report_data = caching_report_datas_service.get(report: report, start_date: start_date.to_date, end_date: end_date.to_date)
        expect(fetched_report_data.id.to_s).to eq(report_data.id.to_s)
        expect(ReportData).to have_received(:find_by).once
      end

      it 'gets cached ReportData' do
        report_data
        caching_report_datas_service.get(report: report, start_date: start_date.to_date, end_date: end_date.to_date)
        allow(ReportData).to receive(:find_by).and_call_original
        fetched_report_data = caching_report_datas_service.get(report: report, start_date: start_date.to_date, end_date: end_date.to_date)
        expect(fetched_report_data.id.to_s).to eq(report_data.id.to_s)
        expect(ReportData).not_to have_received(:find_by)
      end
    end
  end
end
