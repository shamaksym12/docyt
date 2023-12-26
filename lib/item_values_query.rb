# frozen_string_literal: true

class ItemValuesQuery
  def initialize(report:, item_values_params:)
    super()
    @report = report
    @report_datas = []
    @start_date = item_values_params[:from]&.to_date
    @end_date = item_values_params[:to]&.to_date
    @item_identifier = item_values_params[:item_identifier]
    @item = report.find_item_by_identifier(identifier: @item_identifier)
    @current_actual_column = @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
  end

  def item_values
    @report_datas = @report.monthly_report_datas_for_range(start_date: @start_date, end_date: @end_date)
    if @report_datas.length > 1 # When we show first drill down values for multiple months, we show only Actual PTD values.
      item_values_including_total
    else
      item_values_for_a_month
    end
  end

  private

  def item_values_including_total # rubocop:disable Metrics/MethodLength
    total_item_values = []
    item_values = pick_item_values(report_datas: @report_datas)
    if @report.total_column_visible
      if @item.type_config.present? && @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE
        total_report_datas = @item.prior_balance_day_option? ? [@report_datas.first] : [@report_datas.last]
        item_values_for_total = pick_item_values(report_datas: total_report_datas)
      else
        item_values_for_total = item_values
      end
      total_item_values = generate_total_item_value(item_values: item_values_for_total)
    end
    total_item_values + item_values
  end

  def item_values_for_a_month # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    first_drilldown_configuration = ConfigurationsQuery.new.configuration(configuration_id: ConfigurationsQuery::FIRST_DRILLDOWN_CONFIGURATION)
    first_drilldown_columns = first_drilldown_configuration[:columns].map do |first_drilldown_column|
      @report.columns.detect do |column|
        column.type == first_drilldown_column['type'] && column.per_metric == first_drilldown_column['per_metric'] &&
          column.range == first_drilldown_column['range'] && column.year == first_drilldown_column['year']
      end
    end.compact
    column_ids = first_drilldown_columns.map do |column|
      column.id.to_s
    end
    @report_datas.first.item_values.select { |iv| iv.item_identifier == @item_identifier && column_ids.include?(iv.column_id) }
  end

  def pick_item_values(report_datas:)
    report_datas.map { |report_data| generate_item_value(report_data: report_data) }
  end

  def generate_item_value(report_data:)
    item_value = report_data.item_values.detect { |iv| iv.item_id == @item.id.to_s && iv.column_id == @current_actual_column.id.to_s }
    return item_value if item_value.present?

    report_data.item_values.new(item_id: @item.id.to_s, item_identifier: @item.identifier, column_id: @current_actual_column.id.to_s)
  end

  def generate_total_item_value(item_values:)
    total_report_data = ReportData.new(report: @report, start_date: @start_date, end_date: @end_date)
    total_item_value = total_report_data.item_values.new(
      item_id: @item.id.to_s,
      item_identifier: @item.identifier,
      column_id: @current_actual_column.id.to_s,
      value: item_values.map(&:value).compact.sum,
      column_type: item_values[0].column_type
    )
    [total_item_value]
  end
end
