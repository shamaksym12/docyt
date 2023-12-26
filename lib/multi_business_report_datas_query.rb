# frozen_string_literal: true

class MultiBusinessReportDatasQuery # rubocop:disable Metrics/ClassLength
  def initialize(multi_business_report:, report_datas_params:)
    super()
    @multi_business_report = multi_business_report
    @start_date = report_datas_params[:from]&.to_date
    @end_date = report_datas_params[:to]&.to_date
    @current_date = report_datas_params[:current]&.to_date
    @is_daily = report_datas_params[:is_daily]
    @dependent_report_datas = {}
    @multi_business_dependent_report_datas = {}
    @caching_report_datas_service = ItemValues::CachingReportDatasService.new(nil)
  end

  def report_datas
    if @is_daily
      @period_type = ReportData::PERIOD_DAILY
      daily_report_datas
    else
      @period_type = ReportData::PERIOD_MONTHLY
      monthly_report_datas
    end
  end

  private

  def daily_report_datas
    @report_datas = generate_business_daily_report_datas(current_date: @current_date)
    return @report_datas unless @report_datas.length.positive?

    aggregated_report_data = generate_aggregated_report_data(multi_business_report_datas: @report_datas, start_date: @current_date, end_date: @current_date)
    @report_datas.unshift(aggregated_report_data)
    @report_datas
  end

  def generate_business_daily_report_datas(current_date:)
    multi_business_report_datas = []
    @multi_business_report.reports.each do |report|
      report_datas_params = { current: current_date, is_daily: true }
      query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: true)
      multi_business_report_datas << query.report_datas.first
    end
    multi_business_report_datas
  end

  def monthly_report_datas
    @report_datas = generate_business_monthly_report_datas(start_date: @start_date, end_date: @end_date)
    return @report_datas unless @report_datas.length.positive?

    generate_dependency_aggregated_report_data
    aggregated_report_data = generate_aggregated_report_data(multi_business_report_datas: @report_datas, start_date: @start_date, end_date: @end_date)
    @report_datas.unshift(aggregated_report_data)
    @report_datas
  end

  def generate_business_monthly_report_datas(start_date:, end_date:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    multi_business_report_datas = []
    @multi_business_report.reports.each do |report|
      report_datas_params = { from: start_date, to: end_date, aggregation_columns: @multi_business_report.columns }
      query = ReportDatasQuery.new(report: report, report_datas_params: report_datas_params, include_total: true).report_datas_with_dependency
      multi_business_report_datas << query[:report_datas].first
      dependency = query[:dependent_report_datas]
      report.dependent_reports.each do |dependent_report|
        @multi_business_dependent_report_datas[dependent_report.template_id] = [] if @multi_business_dependent_report_datas[dependent_report.template_id].nil?
        @multi_business_dependent_report_datas[dependent_report.template_id] << dependency[dependent_report.template_id] if dependency[dependent_report.template_id].present?
      end
    end
    multi_business_report_datas
  end

  def generate_aggregated_report_data(multi_business_report_datas:, start_date:, end_date:) # rubocop:disable Metrics/MethodLength
    aggregated_report_data = ReportData.new(
      report: multi_business_report_datas[0].report,
      period_type: @period_type,
      start_date: start_date,
      end_date: end_date
    )

    get_config_info(report_datas: multi_business_report_datas, aggregated_report_data: aggregated_report_data)
    @multi_business_report.columns.each do |aggregation_column|
      target_column = aggregated_report_data.report.columns.detect do |column|
        column.type == aggregation_column.type && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
      end
      @items.each do |item|
        update_aggregated_report_data(
          report_datas: multi_business_report_datas,
          aggregated_report_data: aggregated_report_data,
          column: target_column,
          item: item
        )
      end
    end

    aggregated_report_data
  end

  def generate_dependency_aggregated_report_data # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    @multi_business_dependent_report_datas.map do |template_id, report_datas|
      next if report_datas.empty?

      dependent_aggregated_report_data = ReportData.new(
        report: report_datas[0].report,
        period_type: @period_type,
        start_date: @start_date,
        end_date: @end_date
      )
      get_config_info(report_datas: report_datas, aggregated_report_data: dependent_aggregated_report_data)
      @multi_business_report.columns.each do |aggregation_column|
        next unless [Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL].include?(aggregation_column.type)

        target_column = dependent_aggregated_report_data.report.columns.detect do |column|
          column.type == aggregation_column.type && column.range == Column::RANGE_CURRENT && column.year == Column::YEAR_CURRENT
        end
        @items.each do |item|
          update_aggregated_report_data(
            report_datas: report_datas,
            aggregated_report_data: dependent_aggregated_report_data,
            column: target_column,
            item: item
          )
        end
      end
      @dependent_report_datas[template_id] = dependent_aggregated_report_data
    end
  end

  def update_aggregated_report_data(report_datas:, aggregated_report_data:, item:, column:) # rubocop:disable Metrics/MethodLength
    return aggregated_report_data if column.nil?

    if [Column::TYPE_ACTUAL, Column::TYPE_GROSS_ACTUAL].include?(column.type)
      Aggregation::MultiBusinessItemActualsValueRecalculator.call(
        report_datas: report_datas,
        report_data: aggregated_report_data,
        dependent_report_datas: @dependent_report_datas,
        column: column,
        item: item,
        actual_columns: @actual_columns
      )
    else
      item_value_creator = ItemValues::ItemValueCreator.new(
        report_data: aggregated_report_data,
        standard_metrics: nil,
        dependent_report_datas: @dependent_report_datas,
        all_business_chart_of_accounts: nil,
        accounting_classes: nil,
        caching_report_datas_service: @caching_report_datas_service,
        caching_general_ledgers_service: nil
      )
      item_value_creator.call(column: column, item: item)
    end
  end

  def get_config_info(report_datas:, aggregated_report_data:)
    @actual_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_ACTUAL)
    @items = ItemFactory.report_items(report: aggregated_report_data.report).items
  end

  def all_columns(report_datas:, column_type:)
    columns = {}
    report_datas.each do |report_data|
      column = report_data.report.columns.detect do |cl|
        cl.type == column_type && cl.range == Column::RANGE_CURRENT && cl.year == Column::YEAR_CURRENT
      end
      next if column.nil?

      columns[report_data.id.to_s] = column
    end
    columns
  end
end
