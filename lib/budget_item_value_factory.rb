# frozen_string_literal: true

class BudgetItemValueFactory
  include DocytLib::Utils::DocytInteractor

  def upsert_batch(budget_item:, budget_item_values: [])
    total = 0
    budget_item_values.each do |item_value|
      total += item_value[:value]
      budget_item_value = budget_item.budget_item_values.find_or_initialize_by(month: item_value[:month])
      budget_item_value.value = item_value[:value]
    end
    budget_item.is_blank = total.zero?
    budget_item.save!
  end
end
