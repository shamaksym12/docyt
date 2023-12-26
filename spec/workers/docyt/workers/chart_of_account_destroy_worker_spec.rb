# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe ChartOfAccountDestroyWorker do
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
      let(:parent_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'parent_item') }
      let(:child_item) { report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', parent_id: parent_item.id.to_s) }
      let(:chart_of_account_id) { Faker::Number.number(digits: 10) }
      let(:item_account) { child_item.item_accounts.find_or_create_by!(chart_of_account_id: chart_of_account_id, accounting_class_id: 1) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        context 'when business_chart_of_account_destroyed is occurred' do
          let(:event) do
            DocytLib.async.events.business_chart_of_account_destroyed(
              business_id: business_id,
              chart_of_account_id: chart_of_account_id
            ).body
          end

          it 'deletes corresponding item_Account' do
            item_account
            perform
            expect(child_item.reload.item_accounts.find_by(chart_of_account_id: chart_of_account_id)).to be_nil
          end
        end
      end
    end
  end
end
