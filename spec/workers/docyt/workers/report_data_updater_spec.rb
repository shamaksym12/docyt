# frozen_string_literal: true

require 'rails_helper'
require 'redlock'

module Docyt
  module Workers # rubocop:disable Metrics/ModuleLength
    RSpec.describe ReportDataUpdater do
      before do
        allow(RefillReportService).to receive(:new).and_return(refill_report_service)
        allow(ReportFactory).to receive(:new).and_return(report_factory)
        allow(Rollbar).to receive(:error)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:owner_report) do
        create(:advanced_report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement',
                                 slug: 'owners_operating_statement', missing_transactions_calculation_disabled: false)
      end
      let(:refill_report_service) { instance_double(RefillReportService, refill_report_data: true) }
      let(:report_factory) { instance_double(ReportFactory, handle_update_error: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'with monthly period' do
          let(:event) do
            DocytLib.async.events.refresh_report_data(
              report_id: owner_report.id.to_s,
              start_date: '2023-01-01',
              end_date: '2023-01-31',
              is_manual_update: true
            ).body
          end

          it 'calls refill_report_data method of RefillReportService' do
            perform
            expect(refill_report_service).to have_received(:refill_report_data).once
          end
        end

        context 'with daily period' do
          let(:event) do
            DocytLib.async.events.refresh_report_data(
              report_id: owner_report.id.to_s,
              start_date: '2023-01-01',
              end_date: '2023-01-01',
              is_manual_update: true
            ).body
          end

          it 'calls refill_report_data method of RefillReportService' do
            perform
            expect(refill_report_service).to have_received(:refill_report_data).once
          end
        end

        context 'when report_data is not updatable' do
          before do
            report_data = ReportData.create!(report: owner_report, start_date: '2023-01-01', end_date: '2023-01-31', period_type: ReportData::PERIOD_MONTHLY)
            allow(ReportData).to receive(:find_by).and_return(report_data)
            allow(report_data).to receive(:should_update?).and_return(false)
          end

          let(:event) do
            DocytLib.async.events.refresh_report_data(
              report_id: owner_report.id.to_s,
              start_date: '2023-01-01',
              end_date: '2023-01-31',
              is_manual_update: true
            ).body
          end

          it 'publishes report_data_not_changed event' do
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
          end

          it 'does not call refill_report_data method of RefillReportService' do
            perform
            expect(refill_report_service).not_to have_received(:refill_report_data)
          end
        end

        context 'when sync_report_infos raises errors' do
          let(:server_api_error) { DocytServerClient::ApiError.new({ message: 'Internal Server Error', code: 503 }) }
          let(:server_api_error2) { DocytServerClient::ApiError.new({ message: 'Internal Server Error', code: 500 }) }
          let(:server_api_error3) { MetricsServiceClient::ApiError.new({ message: 'Internal Server Error', code: 500 }) }
          let(:event) do
            DocytLib.async.events.refresh_report_data(
              report_id: owner_report.id.to_s,
              start_date: '2023-01-01',
              end_date: '2023-01-31',
              is_manual_update: true
            ).body
          end

          it 'logs the error for MetricsServiceClient::ApiError with Rollbar' do
            allow(refill_report_service).to receive(:refill_report_data).and_raise(server_api_error3)
            perform
            expect(report_factory).to have_received(:handle_update_error).once
          end

          it 'logs the error for DocytServerClient::ApiError with Rollbar' do
            allow(refill_report_service).to receive(:refill_report_data).and_raise(server_api_error2)
            perform
            expect(report_factory).to have_received(:handle_update_error).once
          end

          it 'rerun worker' do
            allow(refill_report_service).to receive(:refill_report_data).and_raise(server_api_error)
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
          end
        end

        context 'when the queue is already locked' do
          before do
            lock_info
          end

          after do
            lock_manager.unlock(lock_info)
          end

          let(:lock_manager) { ::Redlock::Client.new([DocytLib.config.locking.redis_url]) }
          let(:lock_key) { "update_report_data_#{owner_report.id}_2023-01-01_2023-01-01" }
          let(:lock_info) { lock_manager.lock("#{DocytLib.service.name}:#{lock_key}", 1000) }

          let(:event) do
            DocytLib.async.events.refresh_report_data(
              report_id: owner_report.id.to_s,
              start_date: '2023-01-01',
              end_date: '2023-01-01',
              is_manual_update: true
            ).body
          end

          it 'publishes message with some delay' do
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
            events = DocytLib.async.event_queue.events
            expect(events[0].headers['x-delay']).to eq(ReportDataUpdater::DELAY_FOR_RESCHEDULE_TIME)
          end
        end
      end
    end
  end
end
