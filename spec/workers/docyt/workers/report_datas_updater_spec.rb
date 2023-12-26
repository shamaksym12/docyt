# frozen_string_literal: true

require 'rails_helper'
require 'redlock'

module Docyt
  module Workers # rubocop:disable Metrics/ModuleLength
    RSpec.describe ReportDatasUpdater do
      before do
        allow(ReportDatasUpdateFactory).to receive(:new).and_return(updater_factory)
        allow(ReportsInReportServiceUpdater).to receive(:new).and_return(report_service_updater)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

      let(:owner_report) { create(:report, name: 'Owners Report', report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement') }

      let(:report_data) { owner_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-03-05', end_date: '2021-03-05') }

      let(:updater_factory) { instance_double(ReportDatasUpdateFactory, update: true) }

      let(:report_service_updater) { instance_double(ReportsInReportServiceUpdater, update_all_reports: true, update_report: true) }

      let(:lock_manager) { ::Redlock::Client.new([DocytLib.config.locking.redis_url]) }
      let(:lock_key) { "fetch_general_ledger_for_service_#{report_service.id}" }
      let(:lock_info) { lock_manager.lock("#{DocytLib.service.name}:#{lock_key}", 1000) }

      describe '#handle_refresh_report_datas' do
        subject(:perform) { described_class.new.perform(event) }

        let(:event) do
          DocytLib.async.events.refresh_report_datas(
            report_service_id: report_service.id.to_s,
            report_id: owner_report.id.to_s,
            start_date: '03/05/2021',
            end_date: '03/05/2021',
            period_type: ReportData::PERIOD_DAILY
          ).body
        end

        it 'updates report datas' do
          perform
          expect(updater_factory).to have_received(:update)
        end

        context 'when the queue is already locked' do
          before do
            lock_info
          end

          after do
            lock_manager.unlock(lock_info)
          end

          it 'publishes message with some delay' do
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
            events = DocytLib.async.event_queue.events
            expect(events[0].headers['x-delay']).to eq(ReportDatasUpdater::DELAY_FOR_RESCHEDULE_TIME)
          end
        end
      end

      describe '#handle_refresh_report_service' do
        subject(:perform) { described_class.new.perform(event) }

        let(:event) do
          DocytLib.async.events.refresh_report_datas(
            report_service_id: report_service.id.to_s
          ).body
        end

        it 'updates reports in report service' do
          perform
          expect(report_service_updater).to have_received(:update_all_reports)
        end

        context 'when the queue is already locked' do
          before do
            lock_info
          end

          after do
            lock_manager.unlock(lock_info)
          end

          it 'publishes message with some delay' do
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
            events = DocytLib.async.event_queue.events
            expect(events[0].headers['x-delay']).to eq(ReportDatasUpdater::DELAY_FOR_RESCHEDULE_TIME)
          end
        end
      end

      describe '#handle_refresh_report' do
        subject(:perform) { described_class.new.perform(event) }

        let(:event) do
          DocytLib.async.events.refresh_report_datas(
            report_service_id: report_service.id.to_s,
            report_id: owner_report.id.to_s
          ).body
        end

        it 'updates a report' do
          perform
          expect(report_service_updater).to have_received(:update_report)
        end

        context 'when the queue is already locked' do
          before do
            lock_info
          end

          after do
            lock_manager.unlock(lock_info)
          end

          it 'publishes message with some delay' do
            expect do
              perform
            end.to change { DocytLib.async.event_queue.size }.by(1)
            events = DocytLib.async.event_queue.events
            expect(events[0].headers['x-delay']).to eq(ReportDatasUpdater::DELAY_FOR_RESCHEDULE_TIME)
          end
        end
      end
    end
  end
end
