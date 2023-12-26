# frozen_string_literal: true

class Budget
  include Mongoid::Document
  include Mongoid::Timestamps

  STATE_DRAFT = 'draft'
  STATE_PUBLISHED = 'published'
  STATES = [STATE_DRAFT, STATE_PUBLISHED].freeze

  field :name, type: String
  field :year, type: Integer
  field :total_amount, type: Float
  field :creator_id, type: Integer
  field :created_at, type: DateTime
  field :status, type: String, default: STATE_PUBLISHED

  validates :name, presence: true
  validates :year, presence: true
  validates :status, allow_nil: false, inclusion: { in: STATES }

  belongs_to :report_service, class_name: 'ReportService', inverse_of: :budgets
  has_many :actual_budget_items, dependent: :destroy
  has_many :draft_budget_items, dependent: :destroy

  index({ report_service_id: 1, year: 1 })

  def publish!
    copy_budget_item_values(src: draft_budget_items, dst: actual_budget_items)
    self.status = STATE_PUBLISHED
    self.total_amount = total_amount
    save!
  end

  def discard!
    copy_budget_item_values(src: actual_budget_items, dst: draft_budget_items)
    self.status = STATE_PUBLISHED
    save!
  end

  def copy_budget_item_values(src:, dst:) # rubocop:disable Metrics/MethodLength
    dst.each do |dst_budget_item|
      src_budget_item = src.find_by(
        chart_of_account_id: dst_budget_item.chart_of_account_id,
        accounting_class_id: dst_budget_item.accounting_class_id,
        standard_metric_id: dst_budget_item.standard_metric_id
      )
      dst_budget_item.budget_item_values.destroy_all
      src_budget_item.budget_item_values.each do |budget_item_value|
        dst_budget_item.budget_item_values.new(month: budget_item_value.month, value: budget_item_value.value)
      end
      dst_budget_item.is_blank = src_budget_item.is_blank
      dst_budget_item.save!
    end
  end

  def total_amount
    total_amount = 0.0
    actual_budget_items.each do |budget_item|
      next if budget_item.standard_metric_id

      total_amount += budget_item.budget_item_values.sum(:value).round(2)
    end
    total_amount
  end
end
