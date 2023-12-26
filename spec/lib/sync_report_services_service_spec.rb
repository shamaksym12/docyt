# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncReportServicesService, service: true do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }

  describe '#sync' do
    subject(:sync_report_services) { described_class.sync }

    let(:report_service) { create(:report_service) }

    it 'publishes refresh_report_datas event to update report_datas when it has subscription' do
      allow_any_instance_of(ReportService).to receive(:has_active_subscription?).and_return(true) # rubocop:disable RSpec/AnyInstance
      report_service
      expect do
        sync_report_services
      end.to change { DocytLib.async.event_queue.size }.by(1)
    end

    it 'does nothing when it has no subscription' do
      allow_any_instance_of(ReportService).to receive(:has_active_subscription?).and_return(false) # rubocop:disable RSpec/AnyInstance
      report_service
      expect do
        sync_report_services
      end.to change { DocytLib.async.event_queue.size }.by(0)
    end
  end
end
