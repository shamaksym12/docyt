# frozen_string_literal: true

class ServicePermissionManager
  def initialize(user:)
    @current_user = user
  end

  def can_access_multi_business_service(multi_business_report_service_id:)
    multi_business_service_api_instance = DocytServerClient::MultiBusinessReportServiceApi.new
    multi_business_report_service = multi_business_service_api_instance.get_by_user_id(@current_user.id)
    multi_business_report_service_id == multi_business_report_service.id
  end

  def can_access_advanced_report(report:)
    report.report_users.where(user_id: @current_user.id).any?
  end

  def can_access_to_report_service(report_service:, operation:)
    access_control_api = DocytServerClient::AccessControlApi.new
    response = access_control_api.can_access(@current_user.id, report_service.service_id, operation)
    response.can_access
  end
end
