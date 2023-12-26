# frozen_string_literal: true

class ExportReport
  include Mongoid::Document
  include DocytLib::Async::Publisher

  EXPORT_TYPE_MULTI_ENTITY_REPORT = 'multi_entity'
  EXPORT_TYPE_REPORT = 'report'
  EXPORT_TYPE_CONSOLIDATED_REPORT = 'consolidated_report'
  EXPORT_TYPES = [EXPORT_TYPE_MULTI_ENTITY_REPORT, EXPORT_TYPE_REPORT, EXPORT_TYPE_CONSOLIDATED_REPORT].freeze

  field :user_id, type: Integer
  field :export_type, type: String
  field :start_date, type: Date
  field :end_date, type: Date
  field :filter, type: Hash

  belongs_to :report, optional: true
  belongs_to :multi_business_report, optional: true
  belongs_to :report_service, optional: true

  validates :export_type, allow_nil: false, inclusion: { in: EXPORT_TYPES }

  def request_export_report
    publish(events.export_report_requested(export_report_id: id.to_s))
  end
end
