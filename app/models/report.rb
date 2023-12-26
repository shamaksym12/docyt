# frozen_string_literal: true

class Report # rubocop:disable Metrics/ClassLength
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include DocytLib::Async::Publisher

  UPDATE_STATE_QUEUED = 'queued'
  UPDATE_STATE_STARTED = 'started'
  UPDATE_STATE_FINISHED = 'finished'
  UPDATE_STATE_FAILED = 'failed'

  PERIOD_DAILY = 'daily'
  PERIOD_MONTHLY = 'monthly'

  DEPARTMENT_REPORT = 'departmental_report'
  REVENUE_REPORT = 'revenue_report'
  VENDOR_REPORT = 'vendor_report'
  UPS_REPORTS = %w[owners_report store_managers_report].freeze
  STORE_MANAGERS_REPORT = 'store_managers_report'
  REVENUE_ACCOUNTING_REPORT = 'revenue_accounting_report'
  UPS_ADVANCED_BALANCE_SHEET_REPORT = 'ups_advanced_balance_sheet'
  UPS_ADVANCED_OWNERS_REPORT = 'owners_report'
  UPS_REVENUE_REPORT = 'ups_revenue_report'

  BASIC_REPORT_CATEGORY = 'basic'
  DEPARTMENT_REPORT_CATEGORY = 'department'

  ERROR_MSG_QBO_NOT_CONNECTED = 'QuickBooks is not connected.'

  field :docyt_service_id, type: Integer # This will be removed later
  field :template_id, type: String
  field :slug, type: String # This field is used to navigate to report in browser. Its value is same with template_id as default.
  field :name, type: String
  field :updated_at, type: DateTime
  field :missing_transactions_calculation_disabled, type: Boolean, default: true
  field :dependent_template_ids, type: Array
  field :update_state, type: String
  field :error_msg, type: String
  field :enabled_budget_compare, type: Boolean, default: true
  field :total_column_visible, type: Boolean, default: true
  field :accounting_class_check_disabled, type: Boolean, default: false
  field :edit_mapping_disabled, type: Boolean, default: false
  field :accepted_accounting_class_ids, type: Array, default: []
  field :accepted_account_types, type: Array, default: []
  field :accepted_chart_of_account_ids, type: Array, default: []
  field :enabled_blank_value_for_metric, type: Boolean, default: false

  validates :template_id, presence: true
  validates :slug, presence: true, uniqueness: { scope: :report_service_id }
  validates :name, presence: true

  embeds_many :archived_items, class_name: 'Item'
  embeds_many :items, class_name: 'Item'
  embeds_many :columns, class_name: 'Column'
  embeds_many :report_users, class_name: 'ReportUser'

  belongs_to :report_service, class_name: 'ReportService', inverse_of: :reports
  has_many :report_datas, class_name: 'ReportData', inverse_of: :report, dependent: :delete_all
  has_many :unincluded_line_item_details, class_name: 'Quickbooks::UnincludedLineItemDetail', inverse_of: :report, dependent: :delete_all

  index({ report_service_id: 1, slug: 1 }, { unique: true })
  index 'items.order' => 1
  index 'items.item_accounts.chart_of_account_id' => 1

  delegate :factory_class, to: :report_template

  def linked_chart_of_account_ids
    chart_of_account_ids = []
    items.each do |item|
      chart_of_account_ids += item.mapped_item_accounts.pluck(:chart_of_account_id).uniq
    end
    chart_of_account_ids.uniq
  end

  def find_item_by_identifier(identifier:)
    items.detect { |item| item.identifier == identifier }
  end

  def find_item_by_id(id:)
    items.detect { |item| item._id.to_s == id }
  end

  def all_item_accounts
    items.sort_by(&:order).map { |item| item.item_accounts.sort_by { |accnt| [accnt[:chart_of_account_id], accnt[:accounting_class_id]].join(';') } }.flatten
  end

  def departmental_report?
    template_id == DEPARTMENT_REPORT
  end

  def detect_column(type:, range:, year: nil)
    if year.present?
      columns.detect { |column| column.type == type && column.range == range && column.year == year }
    else
      columns.detect { |column| column.type == type && column.range == range }
    end
  end

  def dependent_reports
    return [] if dependent_template_ids.blank?

    report_service.reports.where(slug: { '$in': dependent_template_ids })
  end

  def enabled_default_mapping
    items.each do |item|
      return true if default_accounts_fieldset?(item: item)
    end
    false
  end

  def report_template
    @report_template ||= ReportTemplate.find_by(template_id: template_id)
  end

  def multi_range_columns
    multi_range_configuration = ConfigurationsQuery.new.configuration(configuration_id: ConfigurationsQuery::MULTI_RANGE_CONFIGURATION)
    multi_range_configuration[:columns].map do |multi_range_column|
      columns.detect do |column|
        column.type == multi_range_column['type'] && column.per_metric == multi_range_column['per_metric'] &&
          column.range == multi_range_column['range'] && column.year == multi_range_column['year']
      end
    end.compact
  end

  def root_items
    items.select { |item| item.parent_id.nil? }
  end

  def monthly_report_datas_for_range(start_date:, end_date:)
    monthly_report_datas = []
    date = start_date.at_beginning_of_month
    while date < end_date
      report_data = report_datas.find_by(start_date: date, end_date: date.at_end_of_month, period_type: ReportData::PERIOD_MONTHLY)
      report_data = ReportData.new(report: self, start_date: date, end_date: date.at_end_of_month, period_type: ReportData::PERIOD_MONTHLY) if report_data.nil?
      monthly_report_datas << report_data
      date += 1.month
    end
    monthly_report_datas
  end

  private

  def default_accounts_fieldset?(item:)
    exist = false
    if item.all_child_items.count.positive?
      item.all_child_items.each do |child_item|
        exist = true if default_accounts_fieldset?(item: child_item)
      end
    else
      exist = item.type_config.present? && item.type_config['default_accounts'].present? && item.type_config['default_accounts'].length.positive?
    end
    exist
  end
end
