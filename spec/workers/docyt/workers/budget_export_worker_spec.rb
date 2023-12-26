# frozen_string_literal: true

require 'rails_helper'
module Docyt
  module Workers
    RSpec.describe BudgetExportWorker do
      before do
        allow(ExportExcel::BudgetExportService).to receive(:new).and_return(export_budget_service)
      end

      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:budget) { Budget.create!(report_service: report_service, name: 'budget_2023', year: 2023) }
      let(:export_budget) { ExportBudget.create!(budget: budget, user_id: 10, start_date: '2023-01-01', end_date: '2023-12-31') }
      let(:export_budget_service) { instance_double(ExportExcel::BudgetExportService, call: true) }

      describe '.perform' do
        subject(:perform) { described_class.new.perform(event) }

        let(:event) do
          DocytLib.async.events.export_budget_requested(
            export_budget_id: export_budget.id.to_s
          ).body
        end

        it 'calls ExportExcel::BudgetExportService' do
          perform
          expect(export_budget_service).to have_received(:call)
        end
      end
    end
  end
end
