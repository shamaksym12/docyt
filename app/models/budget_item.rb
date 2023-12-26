# frozen_string_literal: true

class BudgetItem
  include Mongoid::Document

  field :chart_of_account_id, type: Integer
  field :accounting_class_id, type: Integer
  field :position, type: Integer
  field :is_blank, type: Boolean, default: true
  field :_type, type: String

  belongs_to :budget
  belongs_to :standard_metric, class_name: 'StandardMetric', optional: true

  embeds_many :budget_item_values, class_name: 'BudgetItemValue'

  index({ chart_of_account_id: 1, accounting_class_id: 1, standard_metric_id: 1 })
  index({ 'budget_item_values.month': 1 })
end
