# frozen_string_literal: true

class ReportData
  include Mongoid::Document
  include Mongoid::Timestamps

  PERIOD_DAILY = 'daily'
  PERIOD_MONTHLY = 'monthly'
  PERIOD_ANNUALLY = 'annual'
  PERIODS = [PERIOD_DAILY, PERIOD_MONTHLY, PERIOD_ANNUALLY].freeze

  belongs_to :report, class_name: 'Report', inverse_of: :report_datas

  field :period_type, type: String
  field :start_date, type: Date
  field :end_date, type: Date
  field :budget_ids, type: Array, default: []
  field :update_state, type: String
  field :error_msg, type: String
  field :update_started_at, type: DateTime
  field :update_finished_at, type: DateTime

  field :dependency_digests, type: Hash, default: {}

  validates :period_type, allow_nil: false, inclusion: { in: PERIODS }
  validates :start_date, presence: true
  validates :end_date, presence: true

  embeds_many :item_values, class_name: 'ItemValue'
  embeds_many :item_account_values, class_name: 'ItemAccountValue'

  index({ report_id: 1, start_date: 1, end_date: 1 }, { unique: true })

  def recalc_digest
    digests = {}

    dependencies.map do |dependency|
      digests[dependency.class.to_s] = dependency.calculate_digest
    end

    self.dependency_digests = digests
  end

  def recalc_digest!
    recalc_digest
    save!
  end

  def unincluded_transactions_count
    if report.missing_transactions_calculation_disabled
      0
    else
      report.unincluded_line_item_details
            .where(transaction_date: { '$gte' => start_date.to_s, '$lte' => end_date.to_s })
            .count
    end
  end

  def dependent_report_datas
    report_datas = {}
    report.dependent_reports.each do |dependent_report|
      dependent_report_data = dependent_report.report_datas.find_by(start_date: start_date, end_date: end_date)
      report_datas[dependent_report.template_id] = dependent_report_data if dependent_report_data.present?
    end
    report_datas
  end

  def dependencies
    current_dependencies = [
      ReportDependencies::Mapping,
      ReportDependencies::Quickbooks,
      ReportDependencies::ReportTemplate,
      ReportDependencies::Report
    ]

    current_dependencies << ReportDependencies::OtherReports if report.dependent_template_ids.present?
    current_dependencies << ReportDependencies::Budgets if report.columns.where(type: { '$in': Column::BUDGET_TYPES }).present?
    current_dependencies << ReportDependencies::Metrics if report.items.any?(&:releated_to_metric?)

    current_dependencies.map { |klass| klass.new(self) }
  end

  def daily?
    period_type == PERIOD_DAILY && (start_date == end_date)
  end

  def should_update?
    dependencies.any?(&:has_changed?)
  end
end
