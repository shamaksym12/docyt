# frozen_string_literal: true

class ReportDatasQuery
  def initialize(report:, report_datas_params:, include_total:)
    super()
    @report = report
    @report_datas_params = report_datas_params
    @start_date = report_datas_params[:from]&.to_date
    @end_date = report_datas_params[:to]&.to_date
    @current_date = report_datas_params[:current]&.to_date
    @include_total = include_total
    @is_daily = report_datas_params[:is_daily]
    @aggregation_columns = report_datas_params[:aggregation_columns] || report.multi_range_columns
    @dependent_report_datas = dependent_report_datas
  end

  def report_datas
    if @is_daily
      daily_report_datas
    else
      monthly_report_datas
    end
  end

  def report_datas_with_dependency
    { report_datas: report_datas, dependent_report_datas: @dependent_report_datas }
  end

  def last_updated_date
    updated_report_datas = report_datas.reject { |report_data| report_data.updated_at.nil? }
    return nil if updated_report_datas.count < 1

    updated_report_datas.min_by(&:updated_at).updated_at.to_date
  end

  private

  def daily_report_datas
    report_data = @report.report_datas.find_by(start_date: @current_date, end_date: @current_date, period_type: ReportData::PERIOD_DAILY)
    report_data = ReportData.new(report: @report, period_type: ReportData::PERIOD_DAILY, start_date: @current_date, end_date: @current_date) if report_data.nil?
    [report_data]
  end

  def monthly_report_datas
    @report_datas = @report.monthly_report_datas_for_range(start_date: @start_date, end_date: @end_date)
    return @report_datas unless @include_total && @report_datas.length > 1

    @report_datas.unshift(generate_total_report_data)
    @report_datas
  end

  def generate_total_report_data # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    origin_report_datas = @report_datas
    budget_ids = []
    origin_report_datas.each { |rd| budget_ids << rd.budget_ids if rd.start_date.year == @end_date.year }
    total_report_data = ReportData.new(report: @report, period_type: ReportData::PERIOD_MONTHLY, start_date: @start_date, end_date: @end_date, budget_ids: budget_ids.flatten.uniq)
    return total_report_data if @start_date + 1.month > @end_date || origin_report_datas.empty?

    return origin_report_datas.first if origin_report_datas.length == 1

    items = ItemFactory.report_items(report: @report).items
    @aggregation_columns.each do |aggregation_column|
      target_column = @report.columns.detect do |column|
        column.type == aggregation_column.type && column.range == Column::RANGE_CURRENT &&
          (column.year.nil? || column.year == Column::YEAR_CURRENT) && (column.per_metric.nil? || column.per_metric == aggregation_column.per_metric)
      end
      items.each do |item|
        update_total_report_data(
          report_datas: origin_report_datas,
          total_report_data: total_report_data,
          column: target_column,
          item: item
        )
      end
    end
    total_report_data
  end

  def update_total_report_data(report_datas:, total_report_data:, item:, column:) # rubocop:disable Metrics/MethodLength
    return if column.nil?

    if [Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL, Column::TYPE_BUDGET_ACTUAL].include?(column.type)
      Aggregation::ItemActualsValueRecalculator.call(
        report_datas: report_datas,
        report_data: total_report_data,
        dependent_report_datas: @dependent_report_datas,
        column: column,
        item: item
      )
    else
      # We don't save this `total_report_data`. We only calculate values for items(stats, totals and etc).
      item_value_creator = ItemValues::ItemValueCreator.new(
        report_data: total_report_data,
        standard_metrics: nil,
        dependent_report_datas: @dependent_report_datas,
        all_business_chart_of_accounts: nil,
        accounting_classes: nil,
        caching_report_datas_service: caching_report_datas_service,
        caching_general_ledgers_service: nil
      )
      item_value_creator.call(column: column, item: item)
    end
  end

  def dependent_report_datas
    report_datas = {}
    return report_datas unless @include_total

    @report.dependent_reports.each do |dependent_report|
      report_data_query = ReportDatasQuery.new(report: dependent_report, report_datas_params: @report_datas_params, include_total: @include_total)
      next if report_data_query.report_datas.empty?

      report_datas[dependent_report.template_id] = report_data_query.report_datas.first
    end
    report_datas
  end

  def caching_report_datas_service
    @caching_report_datas_service ||= ItemValues::CachingReportDatasService.new(@report.report_service)
  end
end
