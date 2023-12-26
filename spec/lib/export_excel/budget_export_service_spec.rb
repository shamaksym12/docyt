# frozen_string_literal: true

require 'rails_helper'

module ExportExcel
  RSpec.describe BudgetExportService do
    before do
      allow(DocytServerClient::DataExportApi).to receive(:new).and_return(data_export_client_api_instance)
      allow_any_instance_of(StorageServiceClient::FilesApi).to receive(:internal_upload_file).and_return(internal_upload_response) # rubocop:disable RSpec/AnyInstance
      stub_request(:get, /.*internal.*by_token*/).to_return(status: 200, body: '{"file": {"id": "1"}}', headers: { 'Content-Type' => 'application/json' })
    end

    let(:user) { Struct.new(:id).new(1) }
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:budget) { Budget.create!(report_service: report_service, name: 'name1', year: 2023) }
    let(:internal_upload_response) { Struct.new(:to_hash, :success).new(Struct.new(:file).new({ token: '1234' }), true) }
    let(:data_export_params) { Struct.new(:id, :name).new(Faker::Number.number(digits: 10), Faker::Lorem.characters(12)) }
    let(:data_export_response) { Struct.new(:data_export).new(data_export_params) }
    let(:data_export_client_api_instance) do
      instance_double(DocytServerClient::DataExportApi, create_data_export: data_export_response, update_data_export: true)
    end

    describe '#call' do
      subject(:call_export_budget) do
        described_class.call(export_budget: export_budget)
      end

      context 'when exporting budget' do
        before do
          allow(ExportExcel::ExportBudgetDataService).to receive(:new).and_return(export_budget_instance)
        end

        let(:export_budget_instance) do
          instance_double(ExportExcel::ExportBudgetDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_budget) do
          create(:export_budget, budget_id: budget.id, start_date: '2022-12-01', end_date: '2022-12-01')
        end

        it 'uploads XLS file and creates data_export' do
          call_export_budget
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when file creating is failed' do
        before do
          allow(ExportExcel::ExportBudgetDataService).to receive(:new).and_return(export_budget_instance)
        end

        let(:export_budget_instance) do
          instance_double(ExportExcel::ExportBudgetDataService, call: true, success?: false, errors: '')
        end
        let(:export_budget) do
          create(:export_budget, budget_id: budget.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31')
        end

        it 'fails creating XLS file and updates data_export' do
          call_export_budget
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when uploading file is failed' do
        before do
          allow(ExportExcel::ExportBudgetDataService).to receive(:new).and_return(export_budget_instance)
          allow_any_instance_of(StorageServiceClient::FilesApi).to receive(:internal_upload_file).and_raise(StorageServiceClient::ApiError) # rubocop:disable RSpec/AnyInstance
        end

        let(:export_budget_instance) do
          instance_double(ExportExcel::ExportBudgetDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_budget) do
          create(:export_budget, budget_id: budget.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31')
        end

        it 'fails uploading XLS file and updates data_export' do
          call_export_budget
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end
    end
  end
end
