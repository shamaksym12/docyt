# frozen_string_literal: true

class DepartmentReportDatasQuery < ReportDatasQuery
  def initialize(report:, report_datas_params:, include_total:)
    super(report: report, report_datas_params: report_datas_params, include_total: include_total)
    @filter = report_datas_params[:filter] || {}
  end

  def department_report_datas
    department_report_datas = report_datas
    return department_report_datas if @filter[:accounting_class_id].blank?

    department_report_datas.each do |report_data|
      recalculate_report_data(report_data: report_data)
    end
  end

  private

  def recalculate_report_data(report_data:)
    report_data.report.root_items.each do |item|
      recalculate_item_value(report_data: report_data, item: item)
    end
  end

  def recalculate_item_value(report_data:, item:)
    item_value = report_data.item_values.find_by(item_id: item.id.to_s)
    amount = recalculate_total_item_value(report_data: report_data, item: item)
    item_value.value = amount if item_value
  end

  def recalculate_total_item_value(report_data:, item:)
    item.all_item_accounts.each do |item_account|
      next unless item_account.accounting_class_id != @filter[:accounting_class_id]

      total_item = item_account.item.total_item
      item_value = report_data.item_values.detect { |iv| iv.item_id == total_item&.id.to_s }
      return item_value&.value || 0.0
    end

    0.0
  end
end
