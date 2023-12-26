# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budget_items
#
#  id                   :string
#  chart_of_account_id  :integer
#  accounting_class_id  :integer
#  standard_metric_id   :string
#

class BudgetItemSerializer < ActiveModel::MongoidSerializer
  attributes :id, :chart_of_account_id, :accounting_class_id, :standard_metric_id, :standard_metric_name

  has_many :budget_item_values, each_serializer: BudgetItemValueSerializer

  def standard_metric_id
    object.standard_metric_id&.to_s
  end

  def standard_metric_name
    return if object.standard_metric_id.nil?

    standard_metric ||= StandardMetric.find(object.standard_metric_id)
    standard_metric&.name
  end
end
