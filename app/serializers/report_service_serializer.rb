# frozen_string_literal: true

# == Mongoid Information
#
# Document name: ReportService
#
#  id                   :string
#  service_id           :integer
#  business_id          :integer
#  pl_report_id         :string
#  balance_sheet_report_id :string
#  default_budget_id    :string
#

class ReportServiceSerializer < ActiveModel::MongoidSerializer
  attributes :id, :service_id, :business_id
  attributes :pl_report_id, :balance_sheet_report_id, :default_budget_id

  def pl_report_id
    ProfitAndLossReport.find_by(report_service_id: object.id)&._id.to_s
  end

  def balance_sheet_report_id
    BalanceSheetReport.find_by(report_service_id: object.id)&._id.to_s
  end

  def default_budget_id
    object.default_budget_id.to_s
  end
end
