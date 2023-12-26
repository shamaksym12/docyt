# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: columns
#
#  id                   :string
#  type                 :string
#  period               :string
#

class ColumnSerializer < ActiveModel::MongoidSerializer
  attributes :id, :type, :range, :year, :name, :per_metric, :multi_range_total

  def multi_range_total
    object.type == Column::TYPE_ACTUAL && object.range == Column::RANGE_CURRENT && object.year == Column::YEAR_CURRENT
  end
end
