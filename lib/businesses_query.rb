# frozen_string_literal: true

class BusinessesQuery < BaseService
  def available_businesses(user:, template_id:)
    template = TemplatesQuery.new.template(template_id: template_id)
    standard_category_ids = template[:standard_category_ids]
    return [] if standard_category_ids.blank?

    docyt_report_services = fetch_accessible_report_services(current_user: user, standard_category_ids: standard_category_ids)
    docyt_report_service_ids = docyt_report_services.map(&:id)
    available_docyt_report_service_ids = ReportService.where(service_id: { '$in': docyt_report_service_ids }).map do |report_service|
      reports_count = report_service.reports.where(template_id: template_id, report_users: { '$elemMatch' => { user_id: user.id } }).count
      reports_count.positive? ? report_service.service_id : nil
    end
    get_businesses(available_docyt_report_service_ids.compact)
  end

  def by_report_ids(report_ids:, template_id:)
    reports = Report.where(id: { '$in': report_ids }, template_id: template_id)
    docyt_report_service_ids = reports.map { |report| report.report_service.service_id }
    get_businesses(docyt_report_service_ids.uniq)
  end
end
