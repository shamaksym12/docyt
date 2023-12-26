# frozen_string_literal: true

class MultiBusinessReportFactory < BaseService
  attr_accessor :multi_business_report, :multi_business_reports

  def create(current_user:, params:)
    multi_business_report_service_id = fetch_multi_business_report(current_user: current_user).id
    report_service_ids = ReportService.where(service_id: { '$in': params[:report_service_ids] }).pluck(:id) # report_service_ids are ids of ReportService in DocytServer
    reports = Report.where(report_service_id: { '$in': report_service_ids }, slug: params[:template_id]).all
    @multi_business_report = MultiBusinessReport.create!(
      multi_business_report_service_id: multi_business_report_service_id,
      template_id: params[:template_id],
      name: params[:name],
      report_ids: reports.pluck(:id)
    )
    create_columns
  end

  def update_config(multi_business_report:, params:)
    multi_business_report.update!(name: params[:name]) if params[:name].present?
    return if params[:report_service_ids].blank?

    report_service_ids = ReportService.where(service_id: { '$in': params[:report_service_ids] }).pluck(:id) # report_service_ids are ids of ReportService in DocytServer
    reports = Report.where(report_service_id: { '$in': report_service_ids }, slug: multi_business_report.template_id).all
    multi_business_report.update!(report_ids: reports.pluck(:id))
  end

  def update_report(multi_business_report:)
    multi_business_report.reports.each do |report|
      ReportFactory.enqueue_report_update(report: report)
    end
  end

  private

  def create_columns
    report_template = ReportTemplate.find_by(template_id: @multi_business_report.template_id)
    columns = report_template.multi_entity_columns.presence || MultiBusinessReport::DEFAULT_COLUMNS
    columns.each { |column| @multi_business_report.columns.create!(type: column['type'] || column[:type], name: column['name'] || column[:name]) }
  end
end
