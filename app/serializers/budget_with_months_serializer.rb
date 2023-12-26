# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budgets
#
#  id                   :string
#  report_service_id    :integer
#  name                 :string
#  year                 :integer
#  total_amount         :float
#  creator_id           :integer
#  created_at           :datetime
#

class BudgetWithMonthsSerializer < ActiveModel::MongoidSerializer
  attributes :id, :report_service_id, :name, :year, :total_amount, :created_at, :status
  attributes :month_total_amounts

  def month_total_amounts
    amounts = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    object.draft_budget_items.each do |item|
      next if item.standard_metric_id

      item.budget_item_values.each do |value|
        amounts[value.month - 1] += value.value
      end
    end
    amounts
  end

  # For frontend backward compatibility
  def report_service_id
    object.report_service.service_id
  end
end
