# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ReportServiceDeleteWorker do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'when report_service_deleted is occurred' do
          let(:event) do
            DocytLib.async.events.report_service_deleted(
              report_service_id: service_id,
              business_id: business_id
            ).body
          end
          let(:report_service) { create(:report_service, business_id: business_id, service_id: service_id) }

          it 'updates corresponding report_service' do
            report_service
            perform
            expect(report_service.reload.active).to be_falsey
          end
        end
      end
    end
  end
end
