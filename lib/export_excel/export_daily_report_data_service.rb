# frozen_string_literal: true

module ExportExcel
  class ExportDailyReportDataService < ExportBaseService # rubocop:disable Metrics/ClassLength
    def call(report:, current_date:, filter: {}) # rubocop:disable Metrics/MethodLength
      @report = report
      @current_date = current_date
      @is_daily = true
      @total_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      @business = get_business(@report.report_service)
      @last_reconciled_date = Date.new(@business.last_reconciled_month_data.year, @business.last_reconciled_month_data.month) if @business.last_reconciled_month_data
      fetch_business_chart_of_accounts(chart_of_account_ids: report.linked_chart_of_account_ids, business_id: @report.report_service.business_id)
      @is_zero_rows_hidden = if filter.nil? || filter['is_zero_rows_hidden'].nil?
                               false
                             else
                               filter['is_zero_rows_hidden']
                             end
      generate_axlsx(report_name_prefix: report.name)
    end

    private

    def fill_work_book(work_book:)
      report_datas_params = { current: @current_date, include_total: true, is_daily: true }
      report_data_query = ReportDatasQuery.new(report: @report, report_datas_params: report_datas_params, include_total: true)
      daily_report_data = report_data_query.report_datas.first
      return if daily_report_data.blank?

      add_daily_sheets(work_book: work_book, report_data: daily_report_data)
    end

    def add_daily_sheets(work_book:, report_data:)
      add_daily_sheet(work_book: work_book, report_data: report_data, name: 'Consolidated')
      add_daily_sheet(work_book: work_book, report_data: report_data, name: 'Detailed', show_outline_level: true)
    end

    def add_daily_sheet(work_book:, report_data:, name:, show_outline_level: false)
      work_book.add_worksheet(name: name,
                              page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_sheet_static_header(sheet: sheet, report_data: report_data)
        add_daily_sheet_data(sheet: sheet, report_data: report_data, show_outline_level: show_outline_level)
        add_note(sheet: sheet)

        sheet.sheet_view do |view|
          view.show_outline_symbols = true
        end
      end
    end

    def add_daily_sheet_data(sheet:, report_data:, show_outline_level:)
      date_str = report_data.start_date.strftime('%b %d %Y')
      add_sheet_header_for_daily(sheet: sheet, date_str: date_str)
      add_report_to_sheet(sheet: sheet, item_values: report_data.item_values.all, show_outline_level: show_outline_level)
    end

    def add_sheet_static_header(sheet:, report_data:)
      @blank_daily_columns = ['']
      column_widths = [nil, COA_COLUMN_WIDTH]
      sheet.add_row(@blank_daily_columns + ["Company: #{@business.name}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_daily_columns + [@report.name], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_daily_columns + ["As of #{report_data.end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(@blank_daily_columns + ["Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"], style: @left_bolden_style, widths: column_widths)
    end

    def add_sheet_header_for_daily(sheet:, date_str:)
      sheet.add_row([])
      sheet.add_row(['MTD', '', date_str], style: @center_bolden_style, widths: [nil, COA_COLUMN_WIDTH, nil])
    end

    def add_note(sheet:)
      sheet.add_row([])
      sheet.add_row(['Note: “-” denotes that data is unavailable for that date/period in Docyt'])
    end

    def add_report_to_sheet(sheet:, item_values:, show_outline_level:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      @report.root_items.sort_by(&:order).each do |item|
        next if zero_row?(item: item, item_values: item_values)

        sheet.add_row([])
        if item.all_child_items.present?
          sheet.add_row(@blank_daily_columns + [item.name] + @blank_daily_columns, style: @top_border)
          add_one_parent_item(sheet: sheet, item_values: item_values, item: item, show_outline_level: show_outline_level, child_step: 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: item, is_section: true, show_outline_level: show_outline_level)
        end
        next unless item.totals

        daily_columns = daily_column_infos(item: item, item_values: item_values, style: @right_bolden_style)
        mtd_columns = mtd_column_infos(item: item, item_values: item_values, style: @right_bolden_style)
        sheet.add_row(daily_columns[:values] + ["Total #{item.name}"] + mtd_columns[:values],
                      style: daily_columns[:styles] + [@left_bolden_style] + mtd_columns[:styles],
                      widths: daily_columns[:widths] + [COA_COLUMN_WIDTH] + mtd_columns[:widths])
      end
    end

    def add_one_parent_item(sheet:, item_values:, item:, show_outline_level:, child_step: 0)
      item.all_child_items.sort_by(&:order).each do |child_item|
        next if zero_row?(item: child_item, item_values: item_values)

        if child_item.all_child_items.present?
          sheet.add_row(@blank_daily_columns + [item_name(name: child_item.name, child_step: child_step)])
          add_one_parent_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level, child_step: child_step + 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level, child_step: child_step)
        end
      end
    end

    def add_one_child_item(sheet:, item_values:, item:, show_outline_level:, is_section: false, child_step: 0) # rubocop:disable Metrics/ParameterLists
      column_style = is_section ? @top_border : @right_normal_style
      name_column_style = is_section ? @top_border : @left_normal_style
      daily_columns = daily_column_infos(item: item, item_values: item_values, style: column_style)
      mtd_columns = mtd_column_infos(item: item, item_values: item_values, style: column_style)
      sheet.add_row(daily_columns[:values] + [item_name(name: item.name, child_step: child_step)] + mtd_columns[:values],
                    style: daily_columns[:styles] + [name_column_style] + mtd_columns[:styles],
                    widths: daily_columns[:widths] + [COA_COLUMN_WIDTH] + mtd_columns[:widths])
      add_account_items(sheet: sheet, item_values: item_values.all, item: item) if show_outline_level
    end

    def add_account_items(sheet:, item_values:, item:) # rubocop:disable Metrics/AbcSize
      item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @business_chart_of_accounts.select { |category| category.chart_of_account_id == item_account.chart_of_account_id }.first
        next if business_chart_of_account.nil?

        daily_columns = daily_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)
        mtd_columns = mtd_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)
        row = sheet.add_row(daily_columns[:values] + [business_chart_of_account.display_name] + mtd_columns[:values],
                            style: daily_columns[:styles] + [@left_normal_style] + mtd_columns[:styles],
                            widths: daily_columns[:widths] + [COA_COLUMN_WIDTH] + mtd_columns[:widths])
        set_outline_level(row: row, level: 1)
      end
    end

    def daily_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_CURRENT, item_values: item_values, item_account: item_account, style: style)
    end

    def mtd_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_MTD, item_values: item_values, item_account: item_account, style: style)
    end

    def daily_column_infos(item:, item_values:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: Column::RANGE_CURRENT, type: Column::TYPE_ACTUAL, year: Column::YEAR_CURRENT).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        info = item_column_info(item_values: item_values, item: item, column: column, style: style)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def mtd_column_infos(item:, item_values:, style:)
      column_infos(column_range: Column::RANGE_MTD, item: item, item_values: item_values, style: style)
    end

    def column_infos(column_range:, item:, item_values:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        info = item_column_info(item_values: item_values, item: item, column: column, style: style)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def account_column_infos(column_range:, item_values:, item_account:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if column.name.include?('Budget')

        item_value = item_values.find { |item| item.column_id == column._id.to_s }
        info = account_column_info(item_value: item_value, item_account: item_account, style: style)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def item_column_info(item_values:, item:, column:, style:)
      item_value = item_values.find { |value| value.item_id == item._id.to_s and value.column_id == column._id.to_s }
      column_info(item_value: item_value, style: style)
    end

    def set_outline_level(row:, level:)
      return if level.zero?

      row.outline_level = level
      row.hidden = true
    end
  end
end
