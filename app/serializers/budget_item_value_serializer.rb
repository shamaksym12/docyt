# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: budget_item_values
#
#  id                   :string
#  month                :integer
#  value                :float, default: 0.0
#

class BudgetItemValueSerializer < ActiveModel::MongoidSerializer
  attributes :id, :month, :value
end
