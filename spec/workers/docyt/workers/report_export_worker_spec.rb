# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportExportWorker do
      before do
        allow(ExportExcel::ReportExportService).to receive(:new).and_return(factory_instance)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: Faker::Number.number(digits: 10), business_id: Faker::Number.number(digits: 10)) }
      let(:owner_report) do
        create(:advanced_report, name: 'Owners Report', report_service: report_service, docyt_service_id: service_id,
                                 template_id: 'owners_operating_statement', slug: 'owners_operating_statement', missing_transactions_calculation_disabled: false)
      end
      let(:export_report) do
        create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                               report_id: owner_report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31')
      end
      let(:factory_instance) { instance_double(ExportExcel::ReportExportService, call: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        let(:event) do
          DocytLib.async.events.export_report_requested(
            export_report_id: export_report.id.to_s
          ).body
        end

        it 'exports a report' do
          perform
          expect(factory_instance).to have_received(:call).exactly(1)
        end
      end
    end
  end
end
