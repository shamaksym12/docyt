# frozen_string_literal: true

# Deprecated since 09/19/2022
class ReportServiceOptions
  include Mongoid::Document

  belongs_to :report_service, class_name: 'ReportService', inverse_of: :report_service_option
  belongs_to :default_budget, class_name: 'Budget', optional: true

  index({ report_service_id: 1 }, { unique: true })
end
