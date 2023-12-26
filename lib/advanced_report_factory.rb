# frozen_string_literal: true

class AdvancedReportFactory < ReportFactory
  attr_accessor(:report)

  def create(report_service:, report_params:, current_user:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
    report_tempalte = ReportTemplate.find_by(template_id: report_params[:template_id])
    add_error(I18n.t('This template is not ready.')) and return if report_tempalte.draft
    if report_tempalte.category != Report::DEPARTMENT_REPORT_CATEGORY && report_service.reports.find_by(template_id: report_params[:template_id]).present?
      add_error(I18n.t('Report is already created.')) and return
    end

    slug = report_service.reports.find_by(slug: report_params[:template_id]) ? "#{report_params[:template_id]}_#{SecureRandom.hex(2)}" : report_params[:template_id]
    @report = AdvancedReport.new(
      report_service: report_service,
      template_id: report_params[:template_id],
      slug: slug,
      name: report_params[:name]
    )
    unless @report.save
      @errors = @report.errors
      return
    end
    update_report_users(report: @report, current_user: current_user)
    @report.factory_class.sync_report_infos(report: @report)
    ItemAccountFactory.load_default_mapping(report: @report) if @report.enabled_default_mapping
  end
end
