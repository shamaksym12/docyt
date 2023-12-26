# frozen_string_literal: true

module Quickbooks
  # This is base class of all general_ledgers
  class GeneralLedger
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic

    belongs_to :report_service, class_name: 'ReportService', inverse_of: :general_ledgers
    embeds_many :line_item_details, class_name: 'Quickbooks::LineItemDetail', inverse_of: :general_ledger

    field :start_date, type: Date
    field :end_date, type: Date
    field :digest, type: String

    validates :start_date, presence: true
    validates :end_date, presence: true

    index({ report_service_id: 1, start_date: 1, end_date: 1, _type: 1 }, { unique: true })
    index({ 'line_item_details.qbo_id': 1 })

    def set_digest
      update!(digest: calculate_digest)
    end

    def calculate_digest
      sorted_details = line_item_details.sort_by do |item|
        [item[:qbo_id], item[:transaction_date], item[:chart_of_account_qbo_id], item[:accounting_class_qbo_id], item[:amount], item[:vendor_qbo_id]].join(';')
      end
      DocytLib::Encryption::Digest.dataset_digest(sorted_details, %i[transaction_date chart_of_account_qbo_id accounting_class_qbo_id amount vendor_qbo_id])
    end
  end
end
