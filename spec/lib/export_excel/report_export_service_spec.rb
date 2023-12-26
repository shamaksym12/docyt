# frozen_string_literal: true

require 'rails_helper'

module ExportExcel # rubocop:disable Metrics/ModuleLength
  RSpec.describe ReportExportService do
    before do
      allow(DocytServerClient::DataExportApi).to receive(:new).and_return(data_export_client_api_instance)
      allow_any_instance_of(StorageServiceClient::FilesApi).to receive(:internal_upload_file).and_return(internal_upload_response) # rubocop:disable RSpec/AnyInstance
      stub_request(:get, /.*internal.*by_token*/).to_return(status: 200, body: '{"file": {"id": "1"}}', headers: { 'Content-Type' => 'application/json' })
    end

    let(:user) { Struct.new(:id).new(1) }
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
    let(:department_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT, name: 'department_report') }
    let(:multi_business_report) do
      MultiBusinessReport.create!(report_ids: [report.id], multi_business_report_service_id: 111,
                                  template_id: 'owners_operating_statement', name: 'name1')
    end
    let(:internal_upload_response) { Struct.new(:to_hash, :success).new(Struct.new(:file).new({ token: '1234' }), true) }
    let(:data_export_params) { Struct.new(:id, :name).new(Faker::Number.number(digits: 10), Faker::Lorem.characters(12)) }
    let(:data_export_response) { Struct.new(:data_export).new(data_export_params) }
    let(:data_export_client_api_instance) do
      instance_double(DocytServerClient::DataExportApi, create_data_export: data_export_response, update_data_export: true)
    end

    describe '#call' do
      subject(:call_export_report) do
        described_class.call(export_report: export_report)
      end

      context 'when export_report`s type is ExportReport::EXPORT_TYPE_REPORT' do
        before do
          allow(ExportExcel::ExportReportDataService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportReportDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                                 report_id: report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31')
        end

        it 'uploads XLS file and creates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when export_report`s type is DEPARTMENTAL' do
        before do
          allow(ExportExcel::ExportDepartmentReportDataService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportDepartmentReportDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                                 report_id: department_report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31', filter: { 'is_zero_rows_hidden' => true })
        end

        it 'uploads XLS file and creates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when exporting daily report which type is ExportReport::EXPORT_TYPE_REPORT' do
        before do
          allow(ExportExcel::ExportDailyReportDataService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportDailyReportDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                                 report_id: report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-01', filter: { 'is_zero_rows_hidden' => true })
        end

        it 'uploads XLS file and creates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when export_report`s type is ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT' do
        before do
          allow(ExportExcel::ExportMultiBusinessReportDataService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportMultiBusinessReportDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT,
                                 multi_business_report_id: multi_business_report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-01',
                                 filter: { 'is_zero_rows_hidden' => true })
        end

        it 'uploads XLS file and creates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when export_report`s type is ExportReport::EXPORT_TYPE_CONSOLIDATED_REPORT' do
        before do
          allow(ExportExcel::ExportConsolidatedReportService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportConsolidatedReportService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_CONSOLIDATED_REPORT,
                                 report_service_id: report_service.id.to_s, start_date: '2022-12-01', end_date: '2022-12-01')
        end

        it 'uploads XLS file and creates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when file creating is failed' do
        before do
          allow(ExportExcel::ExportReportDataService).to receive(:new).and_return(export_report_instance)
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportReportDataService, call: true, success?: false, errors: '')
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                                 report_id: report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31', filter: { 'is_zero_rows_hidden' => true })
        end

        it 'fails creating XLS file and updates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end

      context 'when uploading file is failed' do
        before do
          allow(ExportExcel::ExportReportDataService).to receive(:new).and_return(export_report_instance)
          allow_any_instance_of(StorageServiceClient::FilesApi).to receive(:internal_upload_file).and_raise(StorageServiceClient::ApiError) # rubocop:disable RSpec/AnyInstance
        end

        let(:export_report_instance) do
          instance_double(ExportExcel::ExportReportDataService, call: true, report_file_path: 'spec/fixtures/files/accounting_classes.json', success?: true)
        end
        let(:export_report) do
          create(:export_report, export_type: ExportReport::EXPORT_TYPE_REPORT,
                                 report_id: report.id.to_s, start_date: '2022-12-01', end_date: '2022-12-31', filter: { 'is_zero_rows_hidden' => false })
        end

        it 'fails uploading XLS file and updates data_export' do
          call_export_report
          expect(data_export_client_api_instance).to have_received(:create_data_export).exactly(1)
          expect(data_export_client_api_instance).to have_received(:update_data_export).exactly(1)
        end
      end
    end
  end
end
