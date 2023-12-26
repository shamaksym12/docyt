# frozen_string_literal: true

class ItemValueFactory < BaseService
  include DocytLib::Helpers::PerformanceHelpers

  def generate_batch( # rubocop:disable Metrics/MethodLength
    report_data:,
    dependent_report_datas:,
    all_business_chart_of_accounts:,
    accounting_classes: []
  )
    @report_data = report_data
    @report = report_data.report
    @dependent_report_datas = dependent_report_datas
    @all_business_chart_of_accounts = all_business_chart_of_accounts
    @accounting_classes = accounting_classes
    @budgets = Budget.where(report_service: @report.report_service, year: @report_data.start_date.year)
    @standard_metrics = StandardMetric.all
    @caching_report_datas_service = ItemValues::CachingReportDatasService.new(@report.report_service)
    @caching_general_ledgers_service = Quickbooks::CachingGeneralLedgersService.new(@report.report_service)

    fill_item_values
    fill_budget_ids
  end
  apm_method :generate_batch

  private

  def columns # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    @columns ||= [
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT),
      @report.detect_column(type: Column::TYPE_VARIANCE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT),
      @report.detect_column(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_YTD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_PRIOR),
      @report.detect_column(type: Column::TYPE_VARIANCE, range: Column::RANGE_YTD),
      @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT)
    ].compact
    @columns += @report.columns.select { |column| column.type == Column::TYPE_ACTUAL_PER_METRIC }
  end

  def fill_item_values # rubocop:disable Metrics/MethodLength
    item_value_creator = ItemValues::ItemValueCreator.new(
      report_data: @report_data,
      standard_metrics: @standard_metrics,
      dependent_report_datas: @dependent_report_datas,
      all_business_chart_of_accounts: @all_business_chart_of_accounts,
      accounting_classes: @accounting_classes,
      caching_report_datas_service: @caching_report_datas_service,
      caching_general_ledgers_service: @caching_general_ledgers_service
    )
    items = ItemFactory.report_items(report: @report).items
    columns.each do |column|
      next if @report_data.daily? && (column.range == Column::RANGE_YTD)

      items.each do |item|
        item_value_creator.call(column: column, item: item)
      end
    end
  end

  def fill_budget_ids
    @report_data.budget_ids = @budgets.map { |budget| budget.id.to_s }
  end
end
