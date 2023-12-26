# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportServiceCreateWorker do
      before do
        allow(ProfitAndLossReportFactory).to receive(:new).and_return(pl_factory_instance)
        allow(BalanceSheetReportFactory).to receive(:new).and_return(balance_sheet_report_factory_instance)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: Faker::Number.number(digits: 10), business_id: Faker::Number.number(digits: 10)) }
      let(:owner_report) do
        create(:advanced_report, name: 'Owners Report', report_service: report_service, docyt_service_id: service_id,
                                 template_id: 'owners_operating_statement', slug: 'owners_operating_statement', missing_transactions_calculation_disabled: false)
      end
      let(:pl_factory_instance) { instance_double(ProfitAndLossReportFactory, create: true) }
      let(:balance_sheet_report_factory_instance) { instance_double(BalanceSheetReportFactory, create: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'when report_service_created is occurred' do
          let(:event) do
            DocytLib.async.events.report_service_created(
              business_id: business_id,
              report_service_id: service_id
            ).body
          end
          let(:event_name) { 'report_service_created' }

          it 'creates report-service' do
            expect do
              perform
            end.to change(ReportService, :count).by(1)
            expect(ReportService.find_by(business_id: business_id)).to be_present
          end

          it 'publishes refresh_report_datas for created report_service' do
            owner_report
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
          end
        end
      end
    end
  end
end
