# frozen_string_literal: true

module Quickbooks
  class LineItemDetail
    include Mongoid::Document

    embedded_in :general_ledger, class_name: 'Quickbooks::GeneralLedger', inverse_of: :line_item_details

    field :amount, type: Float, default: 0.0
    field :transaction_date, type: String
    field :transaction_type, type: String
    field :transaction_number, type: String
    field :link, type: String # This field is temporary field and will be filled temporary in Query
    field :memo, type: String
    field :vendor, type: String
    field :split, type: String
    field :qbo_id, type: String
    field :category, type: String
    field :accounting_class, type: String

    field :chart_of_account_qbo_id, type: String # This id is QBO Account ID
    field :accounting_class_qbo_id, type: String # This id is QBO Class ID
    field :vendor_qbo_id, type: String # This id is QBO Vendor ID
  end
end
