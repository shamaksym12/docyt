# frozen_string_literal: true

# Later we will move DocytServer's report_service to here and we will remove `service_id` definitely.
class ReportService
  include Mongoid::Document

  field :service_id, type: Integer # This is ID of ReportService in DocytServer
  field :business_id, type: Integer # This is ID of Business in DocytServer

  field :ledgers_imported_at, type: DateTime # This is the time that we imported GeneralLedgers from QBO
  field :updated_at, type: DateTime # This is the time that we updated reports for this report_service
  field :active, type: Boolean, default: true

  validates :service_id, presence: true
  validates :business_id, presence: true

  has_many :reports, inverse_of: :report_service, dependent: :delete_all
  has_one :report_service_option, class_name: 'ReportServiceOptions', inverse_of: :report_service, dependent: :delete_all # Deprecated since 09/19/2022
  belongs_to :default_budget, class_name: 'Budget', optional: true
  has_many :budgets, inverse_of: :report_service, dependent: :delete_all
  has_many :general_ledgers, class_name: 'Quickbooks::GeneralLedger', inverse_of: :report_service, dependent: :delete_all

  index({ service_id: 1 }, { unique: true })
  index({ business_id: 1 }, { unique: true })

  def has_active_subscription? # rubocop:disable Naming/PredicateName
    BillingServiceClient::SubscriptionApi.new.get_by_business_id(business_id).subscription.present?
  end
end
