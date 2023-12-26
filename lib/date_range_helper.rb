# frozen_string_literal: true

class DateRangeHelper
  class << self
    def item_value_calculation_date_range(report_data:, column:, item:)
      new.item_value_calculation_date_range(report_data: report_data, column: column, item: item)
    end
  end

  # This returns the date range of the GeneralLedger
  def item_value_calculation_date_range(report_data:, column:, item:)
    return (report_data.start_date..report_data.end_date) unless item.type_config && item.type_config['name'] == Item::TYPE_QUICKBOOKS_LEDGER

    if item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE
      calculation_range_for_balance_sheet_item(report_data: report_data, column: column, item: item)
    else
      common_calculation_range(report_data: report_data, column: column)
    end
  end

  private

  def calculation_range_for_balance_sheet_item(report_data:, column:, item:)
    column_date_delta = date_delta(report_data: report_data, column: column)
    start_date = report_data.start_date - column_date_delta
    start_date -= report_data.daily? ? 1.day : 1.month if item.type_config.dig(Item::BALANCE_SHEET_OPTIONS, Item::BALANCE_DAY_OPTIONS) == Item::PRIOR_BALANCE_DAY
    if report_data.daily?
      (start_date..start_date)
    else
      (start_date.at_beginning_of_month..start_date.at_end_of_month)
    end
  end

  def common_calculation_range(report_data:, column:)
    column_date_delta = date_delta(report_data: report_data, column: column)
    start_date = report_data.start_date - column_date_delta
    end_date = report_data.end_date - column_date_delta
    start_date = start_date.at_beginning_of_year if column.range == Column::RANGE_YTD
    start_date = start_date.at_beginning_of_month if column.range == Column::RANGE_MTD
    (start_date..end_date)
  end

  def date_delta(report_data:, column:) # rubocop:disable Metrics/MethodLength
    case column.year
    when Column::YEAR_PRIOR
      1.year
    when Column::PREVIOUS_PERIOD
      case report_data.period_type
      when ReportData::PERIOD_MONTHLY
        1.month
      when ReportData::PERIOD_DAILY
        1.day
      else
        0
      end
    else
      0
    end
  end
end
