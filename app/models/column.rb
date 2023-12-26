# frozen_string_literal: true

class Column
  include Mongoid::Document

  TYPE_ACTUAL = 'actual'
  TYPE_ACTUAL_PER_METRIC = 'actual_per_metric'
  TYPE_PERCENTAGE = 'percentage'
  TYPE_GROSS_ACTUAL = 'gross_actual'
  TYPE_GROSS_PERCENTAGE = 'gross_percentage'
  TYPE_VARIANCE = 'variance'
  TYPE_VARIANCE_PERCENTAGE = 'variance_percentage'
  TYPE_BUDGET_ACTUAL = 'budget_actual'
  TYPE_BUDGET_PERCENTAGE = 'budget_percentage'
  TYPE_BUDGET_VARIANCE = 'budget_variance'
  TYPES = [
    TYPE_ACTUAL,
    TYPE_ACTUAL_PER_METRIC,
    TYPE_PERCENTAGE,
    TYPE_GROSS_ACTUAL,
    TYPE_GROSS_PERCENTAGE,
    TYPE_VARIANCE,
    TYPE_VARIANCE_PERCENTAGE,
    TYPE_BUDGET_ACTUAL,
    TYPE_BUDGET_PERCENTAGE,
    TYPE_BUDGET_VARIANCE
  ].freeze
  BUDGET_TYPES = [TYPE_BUDGET_ACTUAL, TYPE_BUDGET_PERCENTAGE, TYPE_BUDGET_VARIANCE].freeze
  RANGE_CURRENT = 'current_period'
  RANGE_MTD = 'mtd'
  RANGE_YTD = 'ytd'
  RANGES = [RANGE_CURRENT, RANGE_MTD, RANGE_YTD].freeze
  YEAR_CURRENT = 'current'
  YEAR_PRIOR = 'prior'
  PREVIOUS_PERIOD = 'previous_period'
  PERIODS = [YEAR_CURRENT, YEAR_PRIOR, PREVIOUS_PERIOD].freeze

  field :type, type: String
  field :range, type: String
  field :year, type: String
  field :order, type: Integer
  field :name, type: String
  field :per_metric, type: String

  validates :type, presence: true, inclusion: { in: TYPES }
  validates :range, allow_nil: true, inclusion: { in: RANGES }
  validates :year, allow_nil: true, inclusion: { in: PERIODS }

  embedded_in :report, class_name: 'Report'
end
