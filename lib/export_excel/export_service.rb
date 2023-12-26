# frozen_string_literal: true

module ExportExcel
  class ExportService
    include DocytLib::Utils::DocytInteractor

    DATA_EXPORT_TYPE = 'business_report'
    DATA_EXPORT_READY_STATE = 'ready'
    DATA_EXPORT_ERROR_STATE = 'error'

    def create_data_export(export_data:) # rubocop:disable Metrics/MethodLength
      data_export_api_instance = DocytServerClient::DataExportApi.new
      name_and_business_ids = generate_name_and_business_ids(export_data: export_data)
      response = data_export_api_instance.create_data_export({ business_ids: name_and_business_ids[:business_ids],
                                                               user_id: export_data.user_id,
                                                               data_export: {
                                                                 name: name_and_business_ids[:name],
                                                                 export_type: DATA_EXPORT_TYPE,
                                                                 start_date: export_data.start_date,
                                                                 end_date: export_data.end_date
                                                               } })
      @data_export = response.data_export
    end

    def upload_file(filename:, source_file:)
      storage_service = StorageServiceClient::FilesApi.new
      response = storage_service.internal_upload_file(file: source_file, original_file_name: filename)
      response.to_hash[:file][:token]
    rescue StorageServiceClient::ApiError => e
      DocytLib.logger.error(e.message)
      update_data_export(state: DATA_EXPORT_ERROR_STATE)
      nil
    end

    def update_data_export(state: DATA_EXPORT_READY_STATE, exported_file_token: nil)
      data_export_api_instance = DocytServerClient::DataExportApi.new
      data_export_api_instance.update_data_export({ data_export: {
                                                    state: state,
                                                    exported_file_token: exported_file_token
                                                  } }, @data_export.id)
    end

    private

    def generate_name_and_business_ids(export_data:) # rubocop:disable Metrics/MethodLength
      if export_data.instance_of?(ExportBudget)
        budget = Budget.find(export_data.budget_id)
        { name: "Business Budget: #{budget.name}", business_ids: [budget.report_service.business_id] }
      else
        case export_data.export_type
        when ExportReport::EXPORT_TYPE_REPORT
          report = Report.find(export_data.report_id)
          { name: "Business Report: #{report.name}", business_ids: [report.report_service.business_id] }
        when ExportReport::EXPORT_TYPE_MULTI_ENTITY_REPORT
          multi_business_report = MultiBusinessReport.find(export_data.multi_business_report_id)
          { name: "Multi Entity Report: #{multi_business_report.name}", business_ids: multi_business_report.business_ids }
        else
          report_service = ReportService.find(export_data.report_service_id)
          { name: 'Business Consolidated Report', business_ids: [report_service.business_id] }
        end
      end
    end
  end
end
