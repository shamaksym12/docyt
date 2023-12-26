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

class BudgetSerializer < ActiveModel::MongoidSerializer
  attributes :id, :report_service_id, :name, :year, :total_amount, :created_at
  attributes :creator_name

  # For frontend backward compatibility
  def report_service_id
    object.report_service.service_id
  end
end
