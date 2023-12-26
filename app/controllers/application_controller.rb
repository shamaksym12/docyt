# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ::ActionController::Serialization
  include DocytLib::Helpers::ControllerHelpers
  rescue_from NoPermissionException, with: :render_service_permission_error

  private

  def report
    @report ||= Report.where(_id: params[:report_id]).first
  end

  def report_service
    @report_service ||= ReportService.find_by(service_id: params[:report_service_id])
  end

  def render_service_permission_error(operation)
    render status: 403, json: { error: "User does not have #{operation} permission to this report", no_permission: true }
  end

  def user_access_manager
    @user_access_manager ||= ServicePermissionManager.new(user: secure_user)
  end

  def ensure_report_access(report:, operation:)
    ensure_user_access(business_advisor_id: report.report_service.service_id, op: operation)
    return unless report.is_a?(AdvancedReport)

    raise NoPermissionException, operation unless user_access_manager.can_access_advanced_report(report: report)
  end

  def ensure_multi_business_report(multi_business_report:)
    raise NoPermissionException unless user_access_manager.can_access_multi_business_service(
      multi_business_report_service_id: multi_business_report.multi_business_report_service_id
    )
  end

  def ensure_report_service_access(report_service:, operation:)
    ensure_user_access(business_advisor_id: report_service.service_id, op: operation)
  end
end
