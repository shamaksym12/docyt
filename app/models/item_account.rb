# frozen_string_literal: true

class ItemAccount
  include Mongoid::Document

  field :chart_of_account_id, type: Integer
  field :accounting_class_id, type: Integer

  embedded_in :item, class_name: 'Item'
end
