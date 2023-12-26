# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: items
#
#  id                   :string
#  chart_of_account_id  :integer
#  department_id        :integer
#

class ItemSerializer < ActiveModel::MongoidSerializer
  attributes :id, :name, :order, :item_account_count, :type, :totals, :identifier, :item_accounts, :show
  attributes :use_mapping, :depth_diff
  attributes :type_config, :values_config

  has_many :child_items, each_serializer: ItemSerializer

  def type
    return '' if object.type_config.nil?

    object.type_config[:name]
  end

  def child_items
    object.all_child_items.sort_by(&:order)
  end

  def use_mapping
    object.type_config.present? && object.type_config['use_mapping'].present?
  end
end
