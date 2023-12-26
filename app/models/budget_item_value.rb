# frozen_string_literal: true

class BudgetItemValue
  include Mongoid::Document

  field :month, type: Integer
  field :value, type: Float, default: 0.0

  validates :month, presence: true
  validates :value, presence: true

  embedded_in :budget_item
end
