# frozen_string_literal: true

class DraftBudgetItem < BudgetItem
  field :_type, type: String, default: 'DraftBudgetItem'
end
