# frozen_string_literal: true

class MultiBusinessReport
  include Mongoid::Document

  DEFAULT_COLUMNS = [
    { name: '$', type: Column::TYPE_ACTUAL },
    { name: '%', type: Column::TYPE_PERCENTAGE }
  ].freeze

  field :multi_business_report_service_id, type: Integer
  field :template_id, type: String
  field :name, type: String
  field :report_ids, type: Array

  embeds_many :columns, class_name: 'Column'

  validates :multi_business_report_service_id, presence: true
  validates :template_id, presence: true
  validates :name, presence: true

  def reports
    Report.where(id: { '$in': report_ids }, template_id: template_id).order_by(report_service_id: :asc)
  end

  def businesses
    BusinessesQuery.new.by_report_ids(report_ids: report_ids, template_id: template_id)
  end

  def business_ids
    reports.map { |report| report.report_service.business_id }
  end

  def all_items
    return reports.first.root_items.sort_by(&:order) unless reports.first.root_items.first&.use_derived_mapping?

    items = []
    all_identifiers = []
    reports.each do |report|
      not_added_items = report.root_items.reject { |item| all_identifiers.include?(item.identifier) }
      items += not_added_items
      all_identifiers += not_added_items.pluck(:identifier)
    end
    items.sort_by(&:name)
  end

  def update_daily_report_datas(current_date:)
    reports.each do |report|
      ReportFactory.enqueue_report_datas_update(
        report: report,
        params: { start_date: current_date, end_date: current_date, period_type: ReportData::PERIOD_DAILY }
      )
    end
  end
end
