# frozen_string_literal: true

class ReportFactory < BaseService # rubocop:disable Metrics/ClassLength
  include DocytLib::Helpers::PerformanceHelpers
  include DocytLib::Async::Publisher

  # Higher numbers indicate higher priority in RabbitMQ
  # The default priority of a message is 5
  MANUAL_UPDATE_PRIORITY = 50

  def enqueue_report_update(report:, delay_milliseconds: 0)
    report.update!(update_state: Report::UPDATE_STATE_QUEUED)
    report_service = report.report_service
    publish(
      events.refresh_report_datas(report_service_id: report_service.id.to_s, report_id: report.id.to_s),
      delay_milliseconds: delay_milliseconds,
      priority: ReportFactory::MANUAL_UPDATE_PRIORITY
    )
  end

  def enqueue_report_datas_update(report:, params:)
    update_report_datas_state(report: report, start_date: params[:start_date].to_date, end_date: params[:end_date].to_date, period_type: params[:period_type])
    publish(
      events.refresh_report_datas(
        report_service_id: report.report_service.id.to_s, report_id: report.id.to_s,
        start_date: params[:start_date], end_date: params[:end_date],
        period_type: params[:period_type]
      ),
      priority: ReportFactory::MANUAL_UPDATE_PRIORITY
    )
  end

  def update_report_users(report:, current_user:)
    report.report_users.destroy_all if report.report_users.count.positive?
    user_api_instance = DocytServerClient::UserApi.new
    user_ids = user_api_instance.report_service_admin_users(report.report_service.service_id).users.map(&:id)
    user_ids.each do |user_id|
      report.report_users.create!(user_id: user_id)
    end
    return if current_user.nil? || user_ids.include?(current_user.id)

    report.report_users.create!(user_id: current_user.id)
  end

  def update(report:, report_params:)
    report.update!(name: report_params[:name]) if report_params[:name].present?
    report.update!(accepted_accounting_class_ids: report_params[:accepted_accounting_class_ids]) unless report_params[:accepted_accounting_class_ids].nil?
    report.update!(accepted_chart_of_account_ids: report_params[:accepted_chart_of_account_ids]) unless report_params[:accepted_chart_of_account_ids].nil?
    return if report_params[:user_ids].nil?

    report.report_users.destroy_all
    report_params[:user_ids].each do |user_id|
      report.report_users.create!(user_id: user_id)
    end
  end

  def grant_access(report:, user_id:)
    report.report_users.create!(user_id: user_id)
  end

  def revoke_access(report:, user_id:)
    report_user = report.report_users.detect { |user| user.id.to_s == user_id }
    report_user.destroy!
  end

  def sync_report_infos(report:)
    report_template = ReportTemplate.find_by(template_id: report.template_id)
    sync_advanced_report_infos(report: report, report_template: report_template)
  end

  def handle_update_error(report:, error:)
    report.update!(update_state: Report::UPDATE_STATE_FAILED, error_msg: error.message)
    Rollbar.error(error)
    DocytLib.logger.debug(error.message)
  end

  private

  def update_report_datas_state(report:, start_date:, end_date:, period_type:) # rubocop:disable Metrics/MethodLength
    if period_type == Report::PERIOD_MONTHLY
      date = start_date
      while date < end_date
        period_start_date = Date.new(date.year, date.month, 1)
        period_end_date = Date.new(date.year, date.month, -1)
        report_data = report.report_datas.find_or_initialize_by(start_date: period_start_date, end_date: period_end_date, period_type: period_type)
        report_data.update_state = Report::UPDATE_STATE_QUEUED
        report_data.save!
        date += 1.month
      end
    else
      report_data = report.report_datas.find_or_initialize_by(start_date: start_date, end_date: end_date, period_type: period_type)
      report_data.update_state = Report::UPDATE_STATE_QUEUED
      report_data.save!
    end
  end

  def sync_advanced_report_infos(report:, report_template:)
    sync_columns_with_template(report: report, columns: report_template.columns)
    sync_items_with_template(report: report, items: report_template.items)
    sync_depends_with_template(report: report, dependent_ids: report_template.depends_on)
    sync_missing_transactions_calculation_disabled_with_template(report: report, disabled: report_template.missing_transactions_calculation_disabled)
    sync_enabled_budget_compare(report: report, enabled_budget_compare: report_template.enabled_budget_compare)
    sync_visible_total_column(report: report, total_column_visible: report_template.total_column_visible)
    sync_enabled_blank_value_for_metric(report: report, enabled_blank_value_for_metric: report_template.enabled_blank_value_for_metric)
    sync_edit_mapping_disabled(report: report, edit_mapping_disabled: report_template.edit_mapping_disabled)
  end

  def sync_depends_with_template(report:, dependent_ids:)
    report.update!(dependent_template_ids: dependent_ids) unless dependent_ids.nil?
  end

  def sync_missing_transactions_calculation_disabled_with_template(report:, disabled:)
    report.update!(missing_transactions_calculation_disabled: disabled) unless disabled.nil?
  end

  def sync_enabled_budget_compare(report:, enabled_budget_compare:)
    report.update!(enabled_budget_compare: enabled_budget_compare) unless enabled_budget_compare.nil?
  end

  def sync_visible_total_column(report:, total_column_visible:)
    report.update!(total_column_visible: total_column_visible) unless total_column_visible.nil?
  end

  def sync_enabled_blank_value_for_metric(report:, enabled_blank_value_for_metric:)
    report.update!(enabled_blank_value_for_metric: enabled_blank_value_for_metric) unless enabled_blank_value_for_metric.nil?
  end

  def sync_edit_mapping_disabled(report:, edit_mapping_disabled:)
    report.update!(edit_mapping_disabled: edit_mapping_disabled) unless edit_mapping_disabled.nil?
  end

  def metric_data_type(report:, item_json:) # rubocop:disable Metrics/CyclomaticComplexity
    return item_json.data_type if item_json.data_type.present?
    return if item_json.type.blank? || item_json.type['name'] != 'metric'

    code = item_json.type.dig('metric', 'code')
    return if code.blank?

    @metrics ||= MetricsServiceClient::BusinessMetricApi.new.fetch_business_metrics(report.report_service.business_id)
    metric = @metrics.business_metrics.detect { |met| met.code == code }
    metric&.data_type
  end

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return if items.blank?

    current_order = 0
    items.each do |item_json|
      next if item_json.parent_id.present?

      new_item = report.items.detect { |item| item.identifier == item_json.id }
      new_item ||= report.items.new(identifier: item_json.id)
      metric_type = metric_data_type(report: report, item_json: item_json)
      new_item.update!(name: item_json.name,
                       order: current_order,
                       show: item_json.show.nil? ? true : item_json.show,
                       totals: item_json.totals || false,
                       depth_diff: item_json.depth_diff || 0,
                       type_config: item_json.type,
                       values_config: item_json.values,
                       metric_data_type: metric_type,
                       per_metric_calculation_enabled: item_json.per_metric_calculation_enabled || false)
      current_order = sync_child_items_with_template(parent_item: new_item, items: items, report: report)
      current_order += 1
    end

    report.items.where.not(identifier: { '$in': items.map(&:id) }).destroy_all
  end

  def sync_child_items_with_template(parent_item:, items:, report:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    current_order = parent_item.order
    items.each do |child_item_json|
      next if child_item_json.parent_id != parent_item.identifier

      current_order += 1
      child_item = report.items.detect { |item| item.identifier == child_item_json.id }
      child_item ||= report.items.new(identifier: child_item_json.id)
      metric_type = metric_data_type(report: report, item_json: child_item_json)
      child_item.update!(name: child_item_json.name,
                         order: current_order,
                         show: child_item_json.show.nil? ? true : child_item_json.show,
                         totals: child_item_json.totals || false,
                         negative: child_item_json.negative || false,
                         negative_for_total: child_item_json.negative_for_total || false,
                         depth_diff: child_item_json.depth_diff || 0,
                         type_config: child_item_json.type,
                         values_config: child_item_json.values,
                         account_type: child_item_json.account_type,
                         metric_data_type: metric_type,
                         per_metric_calculation_enabled: child_item_json.per_metric_calculation_enabled || false,
                         parent_id: parent_item.id.to_s)
      current_order = sync_child_items_with_template(parent_item: child_item, items: items, report: report)
    end
    current_order
  end

  def sync_columns_with_template(report:, columns:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    column_ids = []
    order = 0
    columns.each do |column|
      column_object = report.columns.detect do |c|
        c.type == column.type && c.range == column.range &&
          c.year == column.year && c.per_metric == column.per_metric
      end
      if column_object.present?
        column_object.update!(order: order, name: column.name)
      else
        column_object = report.columns.create!(type: column.type, range: column.range, year: column.year, name: column.name,
                                               order: order, per_metric: column.per_metric)
      end
      column_ids << column_object.id.to_s
      order += 1
    end
    report.columns.where.not(_id: { '$in': column_ids }).destroy_all
  end
end
