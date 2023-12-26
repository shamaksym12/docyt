# frozen_string_literal: true

module Quickbooks
  class LineItemDetailSerializer < ActiveModel::MongoidSerializer
    attributes :id, :amount, :transaction_date, :transaction_type, :transaction_number
    attributes :memo, :vendor, :split, :category, :accounting_class
    attributes :qbo_id, :link
  end
end
