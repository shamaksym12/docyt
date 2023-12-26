# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: item_values
#
#  id                   :string
#  value                :string
#  item_id              :ObjectId
#  column_id            :ObjectId
#  value                :Float
#  item_identifier      :string
#

class ItemValueSerializer < ActiveModel::MongoidSerializer
  attributes :id, :item_id, :column_id, :value, :item_identifier, :column_type, :budget_values, :report_data_id

  def report_data_id
    object.report_data.id.to_s
  end
end
