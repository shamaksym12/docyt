# frozen_string_literal: true

class ItemAccountValue
  include Mongoid::Document

  field :item_id, type: String
  field :column_id, type: String
  field :chart_of_account_id, type: Integer
  field :accounting_class_id, type: Integer
  field :name, type: String, default: ''
  field :value, type: Float, default: 0.0
  field :budget_values, type: Array, default: [] # [{budget_id: id, value: 0.0}]
  field :column_type, type: String

  validates :item_id, presence: true
  validates :column_id, presence: true
  validates :chart_of_account_id, presence: true
  validates :value, presence: true

  embedded_in :report_data, class_name: 'ReportData'

  def line_item_details(page:)
    item = report_data.report.find_item_by_id(id: item_id)
    line_item_details_query = Quickbooks::LineItemDetailsQuery.new(
      report: report_data.report,
      item: item,
      params: { chart_of_account_id: chart_of_account_id, accounting_class_id: accounting_class_id, page: page }
    )
    column = report_data.report.columns.detect { |c| c.id.to_s == column_id }
    date_range = DateRangeHelper.item_value_calculation_date_range(report_data: report_data, column: column, item: item)
    line_item_details_query.by_period(start_date: date_range.first, end_date: date_range.last, include_total: true)
  end

  def generate_column_type # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    report = report_data.report
    item = report.find_item_by_id(id: item_id)
    column = report.columns.detect { |c| c.id.to_s == column_id }
    stats_formula = item.values_config[Column::TYPE_ACTUAL] if item.values_config.present?

    if (column.type == Column::TYPE_PERCENTAGE || column.type == Column::TYPE_BUDGET_PERCENTAGE || column.type == Column::TYPE_GROSS_PERCENTAGE || column.type == Column::TYPE_VARIANCE_PERCENTAGE) || # rubocop:disable Layout/LineLength
       (stats_formula.present? && stats_formula['value'].present? && stats_formula['value']['expression'].present? && stats_formula['value']['expression']['operator'] == '%')
      self.column_type = Column::TYPE_PERCENTAGE
    elsif item.type_config.present? && (item.type_config['name'] == Item::TYPE_METRIC || item.type_config['name'] == Item::TYPE_REFERENCE)
      self.column_type = Column::TYPE_VARIANCE
    else
      self.column_type = Column::TYPE_ACTUAL
    end
  end
end
