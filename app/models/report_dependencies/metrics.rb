# frozen_string_literal: true

module ReportDependencies
  class Metrics < Base
    def calculate_digest
      business_id = @report_data.report.report_service.business_id
      value_api_instance = MetricsServiceClient::ValueApi.new
      response = value_api_instance.get_digest(business_id, @report_data.start_date.to_s, @report_data.end_date.to_s)
      response.digest
    end
  end
end
