# frozen_string_literal: true

module AccountValue
  class ItemAccountValuesQuery
    def initialize(report:, item_account_values_params:)
      @report = report
      @report_datas = []
      @start_date = item_account_values_params[:from].to_date
      @end_date = item_account_values_params[:to].to_date
      @item_identifier = item_account_values_params[:item_identifier]
      @item = report.find_item_by_identifier(identifier: @item_identifier)
      @current_actual_column = @report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
    end

    def item_account_values(only_actual_column: true)
      return [] if @item.nil?

      # Now first and second drill down are implemented for only MONTHLY PERIOD
      @report_datas = @report.monthly_report_datas_for_range(start_date: @start_date, end_date: @end_date)
      if @report_datas.length > 1 && only_actual_column # When we show first drill down account values for multiple months, we show only Actual PTD values.
        item_account_values_including_total
      else
        pick_item_account_values(report_datas: @report_datas)
      end
    end

    def item_account_values_for_multi_business_report # rubocop:disable Metrics/MethodLength
      return [] if @item.nil?

      # Now first and second drill down are implemented for only MONTHLY PERIOD
      @report_datas = @report.monthly_report_datas_for_range(start_date: @start_date, end_date: @end_date)
      if @item.type_config.present? && @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE
        @report_datas = @item.prior_balance_day_option? ? [@report_datas.first] : [@report_datas.last]
      end
      item_account_values = pick_item_account_values(report_datas: @report_datas, only_actual_column: true)
      if @item.use_derived_mapping?
        item_account_values
      else
        generate_total_item_account_values(item_account_values: item_account_values)
      end
    end

    private

    def item_account_values_including_total # rubocop:disable Metrics/MethodLength
      total_item_account_values = []
      item_account_values = pick_item_account_values(report_datas: @report_datas, only_actual_column: true)
      if @report.total_column_visible
        if @item.type_config.present? && @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE
          total_report_datas = @item.prior_balance_day_option? ? [@report_datas.first] : [@report_datas.last]
          item_account_values_for_total = pick_item_account_values(report_datas: total_report_datas, only_actual_column: true)
        else
          item_account_values_for_total = item_account_values
        end
        total_item_account_values = generate_total_item_account_values(item_account_values: item_account_values_for_total)
      end
      total_item_account_values + item_account_values
    end

    def pick_item_account_values(report_datas:, only_actual_column: false) # rubocop:disable Metrics/MethodLength
      item_account_values = []
      if only_actual_column
        report_datas.each do |report_data|
          item_account_values += report_data.item_account_values.select { |iav| iav.item_id == @item.id.to_s && iav.column_id == @current_actual_column.id.to_s }
        end
      else
        report_datas.each do |report_data|
          item_account_values += report_data.item_account_values.select { |iav| iav.item_id == @item.id.to_s }
        end
      end
      item_account_values
    end

    def generate_total_item_account_values(item_account_values:)
      return [] if item_account_values.blank?

      total_report_data = ReportData.new(report: @report, start_date: @start_date, end_date: @end_date)
      if @item.use_derived_mapping?
        generate_total_item_account_values_for_derived_mapping(report_data: total_report_data, item_account_values: item_account_values)
      else
        generate_total_item_account_values_for_general_mapping(report_data: total_report_data, item_account_values: item_account_values)
      end
      total_report_data.item_account_values.all
    end

    def generate_total_item_account_values_for_derived_mapping(report_data:, item_account_values:) # rubocop:disable Metrics/MethodLength
      item_account_values.each do |iav|
        total_item_account_value = report_data.item_account_values.detect do |tiav|
          tiav.chart_of_account_id == iav.chart_of_account_id && tiav.accounting_class_id == iav.accounting_class_id
        end
        total_item_account_value ||= report_data.item_account_values.new(
          item_id: iav.item_id, column_id: iav.column_id,
          chart_of_account_id: iav.chart_of_account_id,
          accounting_class_id: iav.accounting_class_id,
          value: 0.0, name: iav.name,
          column_type: iav.column_type
        )
        total_item_account_value.value = total_item_account_value.value + iav.value
      end
    end

    def generate_total_item_account_values_for_general_mapping(report_data:, item_account_values:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      @item.mapped_item_accounts.each do |item_account|
        account_values = item_account_values.select do |iav|
          iav.chart_of_account_id == item_account.chart_of_account_id && iav.accounting_class_id == item_account.accounting_class_id
        end
        total_value = account_values.map(&:value).sum || 0.0
        report_data.item_account_values.new(
          item_id: account_values.first&.item_id, column_id: account_values.first&.column_id,
          chart_of_account_id: item_account.chart_of_account_id,
          accounting_class_id: item_account.accounting_class_id,
          value: total_value, name: account_values.first&.name,
          column_type: account_values.first&.column_type
        )
      end
    end
  end
end
