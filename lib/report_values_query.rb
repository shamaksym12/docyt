# frozen_string_literal: true

class ReportValuesQuery
  def initialize(report_service:, report_values_params:)
    @report_service = report_service
    @slug = report_values_params[:slug] || report_values_params[:template_id]
    @start_date = report_values_params[:from]&.to_date
    @end_date = report_values_params[:to]&.to_date
    @item_identifier = report_values_params[:item_identifier]
    @period_type = report_values_params[:period_type]
    @column_year = report_values_params[:column_year] || Column::YEAR_CURRENT
    @column_type = report_values_params[:column_type] || Column::TYPE_ACTUAL
    @column_per_metric = report_values_params[:column_per_metric].presence
  end

  def report_values
    @report = @report_service.reports.find_by(slug: @slug)
    if @report
      generate_report_values(report_column_id)
    else
      []
    end
  end

  private

  def generate_report_values(column_id)
    report_values = []
    report_datas = @report.report_datas.where(start_date: { '$gt' => (@start_date - 1.day) }, end_date: { '$lt' => (@end_date + 1.day) }, period_type: @period_type)
    report_datas.each do |report_data|
      item_value = report_data.item_values.detect { |iv| iv.item_identifier == @item_identifier && iv.column_id == column_id }
      next if item_value.nil?

      report_values << { date: report_data.start_date, amount: item_value.value }
    end
    report_values
  end

  def report_column_id
    report_column = @report.columns.detect do |column|
      column.type == @column_type &&
        column.range == Column::RANGE_CURRENT &&
        column.year == @column_year &&
        column.per_metric == @column_per_metric
    end
    report_column.id.to_s
  end
end
