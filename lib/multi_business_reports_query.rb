# frozen_string_literal: true

class MultiBusinessReportsQuery < BaseService
  def multi_business_reports(current_user:)
    multi_business_report_service = fetch_multi_business_report(current_user: current_user)
    MultiBusinessReport.where(multi_business_report_service_id: multi_business_report_service.id).all
  end
end
