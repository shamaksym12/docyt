# frozen_string_literal: true

# == Mongoid Information
#
# Document name: multi_business_reports
#
#  id                                   :string
#  multi_business_report_service_id     :integer
#  template_id                          :string
#  name                                 :string
#

class MultiBusinessReportSerializer < ActiveModel::MongoidSerializer
  include ActionView::Helpers::DateHelper
  attributes :id, :multi_business_report_service_id, :template_id, :name, :last_updated_date, :businesses, :columns
  has_many :reports, each_serializer: ReportSerializer

  delegate :reports, to: :object

  def last_updated_date
    updated_reports = reports.reject { |report| report.updated_at.nil? }
    return nil if updated_reports.count < 1

    "#{time_ago_in_words(updated_reports.max_by(&:updated_at).updated_at)} ago"
  end
end
