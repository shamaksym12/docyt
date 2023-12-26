# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: item_accounts
#
#  id                   :string
#  chart_of_account_id  :integer
#  department_id        :integer
#

class ItemAccountSerializer < ActiveModel::MongoidSerializer
  attributes :id, :chart_of_account_id, :accounting_class_id, :item_id

  def item_id
    object.item._id.to_s
  end
end
