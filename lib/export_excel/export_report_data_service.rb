# frozen_string_literal: true

module ExportExcel
  class ExportReportDataService < ExportBaseService # rubocop:disable Metrics/ClassLength
    # Report main column positions
    CENTER = 'center' # default main column position
    LEFT = 'left'

    def call(report:, start_date:, end_date:, filter: {}) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      @report = report
      @start_date = start_date
      @end_date = end_date
      @filter = filter
      @total_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      @business = get_business(@report.report_service)
      @last_reconciled_date = Date.new(@business.last_reconciled_month_data.year, @business.last_reconciled_month_data.month) if @business.last_reconciled_month_data
      @main_column_position = @report.report_template&.export_parameters&.dig('main_column_position') || CENTER
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
      report_datas_params = { from: @start_date, to: @end_date }
      report_data_query = ReportDatasQuery.new(report: @report, report_datas_params: report_datas_params, include_total: true)
      monthly_report_datas = report_data_query.report_datas
      return if monthly_report_datas.blank?

      add_sheets(work_book: work_book, report_datas: monthly_report_datas)
    end

    def add_sheets(work_book:, report_datas:)
      if report_datas.length > 1
        add_total_sheets(work_book: work_book, report_datas: report_datas)
      elsif report_datas.length == 1
        add_monthly_sheets(work_book: work_book, report_data: report_datas[0])
      end
    end

    def add_total_sheets(work_book:, report_datas:)
      add_total_sheet(work_book: work_book, report_datas: report_datas, name: 'TOTAL') if @report.total_column_visible
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        sheet_name = "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
        add_monthly_sheet(work_book: work_book, report_data: report_data, name: sheet_name, show_outline_level: true)
      end
    end

    def add_total_sheet(work_book:, report_datas:, name:)
      work_book.add_worksheet(name: name, page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_total_sheet_static_header(sheet: sheet, report_datas: report_datas)
        add_total_sheet_data(sheet: sheet, report_datas: report_datas)

        sheet.sheet_view do |view|
          view.show_outline_symbols = true
        end
      end
    end

    def add_total_sheet_data(sheet:, report_datas:)
      add_total_sheet_header(sheet: sheet, report_datas: report_datas)
      add_total_to_sheet(sheet: sheet, report_datas: report_datas)
      add_note(sheet: sheet)
    end

    def add_monthly_sheets(work_book:, report_data:)
      add_monthly_sheet(work_book: work_book, report_data: report_data, name: 'Consolidated')
      add_monthly_sheet(work_book: work_book, report_data: report_data, name: 'Detailed', show_outline_level: true) if @report.is_a?(AdvancedReport)
    end

    def add_monthly_sheet(work_book:, report_data:, name:, show_outline_level: false)
      work_book.add_worksheet(name: name,
                              page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_sheet_static_header(sheet: sheet, report_data: report_data)
        add_monthly_sheet_data(sheet: sheet, report_data: report_data, show_outline_level: show_outline_level)
        add_note(sheet: sheet)

        sheet.sheet_view do |view|
          view.show_outline_symbols = true
        end
      end
    end

    def add_monthly_sheet_data(sheet:, report_data:, show_outline_level:)
      add_sheet_header(sheet: sheet)
      add_report_to_sheet(sheet: sheet, item_values: report_data.item_values.all, show_outline_level: show_outline_level)
    end

    def add_sheet_static_header(sheet:, report_data:) # rubocop:disable Metrics/MethodLength
      @blank_ptd_columns = []
      column_widths = []
      @report.columns.where(range: Column::RANGE_CURRENT).order_by(order: :asc).each do |column|
        next if should_skip_column?(column)

        @blank_ptd_columns << ''
        column_widths << nil
      end
      column_widths = add_coa_column_width(column_widths)

      items = [
        "Company: #{@business.name}",
        @report.name,
        "As of #{report_data.end_date.strftime('%m/%d/%Y')}",
        "Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"
      ]

      items.each do |item|
        row = combine_row_sections(ptd: @blank_ptd_columns, item: item)
        sheet.add_row(row, style: @left_bolden_style, widths: column_widths)
      end
    end

    def add_coa_column_width(column_widths)
      return column_widths.unshift(COA_COLUMN_WIDTH) if @main_column_position == LEFT

      column_widths << COA_COLUMN_WIDTH
      column_widths
    end

    def add_sheet_header(sheet:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      ptd_column_names = []
      column_widths = []
      @report.columns.where(range: Column::RANGE_CURRENT).order_by(order: :asc).each do |column|
        next if should_skip_column?(column)

        ptd_column_names << column.name
        column_widths << nil
      end
      column_widths = add_coa_column_width(column_widths)
      ytd_column_names = []
      @report.columns.where(range: Column::RANGE_YTD).order_by(order: :asc).each do |column|
        next if should_skip_column?(column)

        ytd_column_names << column.name
        column_widths << nil
      end
      sheet.add_row([])
      if @report.template_id == Report::STORE_MANAGERS_REPORT
        sheet.merge_cells("#{Axlsx.cell_r(0, 5)}:#{Axlsx.cell_r(3, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(4, 5)}:#{Axlsx.cell_r(7, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(9, 5)}:#{Axlsx.cell_r(12, 5)}")
        sheet.merge_cells("#{Axlsx.cell_r(13, 5)}:#{Axlsx.cell_r(16, 5)}")
        sheet.add_row(['PTD', '', '', '', 'PTD LY', '', '', '', '', 'YTD', '', '', '', 'YTD LY', '', '', ''], style: @center_bolden_style)
      end

      values = combine_row_sections(ptd: ptd_column_names, ytd: ytd_column_names, item: '')
      sheet.add_row(values, style: @center_bolden_style, widths: column_widths)
    end

    def add_note(sheet:)
      @blank_ptd_columns ||= []
      sheet.add_row([])
      sheet.add_row(combine_row_sections(ptd: @blank_ptd_columns, item: 'Note: “-” denotes that data is unavailable for the Period'))
    end

    def add_total_sheet_static_header(sheet:, report_datas:) # rubocop:disable Metrics/MethodLength
      @blank_monthly_columns = []
      total_columns = multi_range_total_columns
      report_datas.each do |_report_data|
        (1..total_columns.length).each do |_|
          @blank_monthly_columns << ''
        end
      end
      sheet.add_row(["Company: #{@business.name}"], style: @left_bolden_style)
      sheet.add_row([@report.name], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
      sheet.add_row(["As of #{@end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
      sheet.add_row(["Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"], style: @left_bolden_style, widths: [COA_COLUMN_WIDTH])
    end

    def add_total_sheet_header(sheet:, report_datas:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      sheet.add_row([])
      total_columns = multi_range_total_columns
      column_count = total_columns.length
      months_column_names = ['', 'Total']
      multi_range_column_names = ['']
      (1..column_count).each do |column_index|
        months_column_names << '' unless column_index == 1
        multi_range_column_names << total_columns[column_index - 1].name
      end
      sheet.merge_cells("#{Axlsx.cell_r(1, 5)}:#{Axlsx.cell_r(column_count, 5)}")
      column_widths = []
      column_widths << COA_COLUMN_WIDTH
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        months_column_names << "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
        (1..column_count).each do |column_index|
          months_column_names << '' unless column_index == 1
          multi_range_column_names << total_columns[column_index - 1].name
        end
        sheet.merge_cells("#{Axlsx.cell_r((index * column_count) + 1, 5)}:#{Axlsx.cell_r((index + 1) * column_count, 5)}")
        column_widths << nil
      end
      sheet.add_row(months_column_names, style: @center_bolden_style, widths: column_widths)
      sheet.add_row(multi_range_column_names, style: @center_bolden_style, widths: column_widths) if column_count > 1
    end

    def add_report_to_sheet(sheet:, item_values:, show_outline_level:) # rubocop:disable Metrics/MethodLength
      @report.root_items.sort_by(&:order).each do |item|
        next if zero_row?(item: item, item_values: item_values)

        sheet.add_row([])
        if item.all_child_items.present?
          values = combine_row_sections(ptd: @blank_ptd_columns, ytd: @blank_ptd_columns, item: item.name)
          sheet.add_row(values, style: @top_border)
          add_one_parent_item(sheet: sheet, item_values: item_values, item: item, show_outline_level: show_outline_level, child_step: 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: item, is_section: true, show_outline_level: show_outline_level)
        end
      end
    end

    def add_total_to_sheet(sheet:, report_datas:)
      @report.root_items.sort_by(&:order).each do |item|
        next if total_zero_row?(item: item, report_datas: report_datas, is_total: true)

        sheet.add_row([])
        if item.all_child_items.present?
          sheet.add_row([item.name] + @blank_monthly_columns, style: @top_border)
          add_one_parent_item_for_total(sheet: sheet, item: item, report_datas: report_datas, child_step: 1)
        else
          add_one_child_item_for_total(sheet: sheet, item: item, report_datas: report_datas, is_section: true)
        end
      end
    end

    def add_one_parent_item(sheet:, item_values:, item:, show_outline_level:, child_step: 0) # rubocop:disable Metrics/MethodLength
      item.all_child_items.sort_by(&:order).each do |child_item|
        next if zero_row?(item: child_item, item_values: item_values)

        if child_item.all_child_items.present?
          if child_item.type_config.present?
            add_one_child_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level, child_step: child_step)
          else
            values = combine_row_sections(ptd: @blank_ptd_columns, item: item_name(name: child_item.name, child_step: child_step))
            sheet.add_row(values)
          end
          add_one_parent_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level, child_step: child_step + 1)
        else
          add_one_child_item(sheet: sheet, item_values: item_values, item: child_item, show_outline_level: show_outline_level, child_step: child_step)
        end
      end
    end

    def add_one_child_item(sheet:, item_values:, item:, show_outline_level:, is_section: false, child_step: 0) # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/MethodLength
      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      ptd_columns = ptd_column_infos(item: item, item_values: item_values, style: values_styles.first)
      ytd_columns = ytd_column_infos(item: item, item_values: item_values, style: values_styles.first)

      row_values = combine_row_sections(ptd: ptd_columns[:values], ytd: ytd_columns[:values], item: item_name(name: item.name, child_step: child_step))
      row_styles = combine_row_sections(ptd: ptd_columns[:styles], ytd: ytd_columns[:styles], item: values_styles.last)

      row = sheet.add_row
      row_values.each_with_index do |value, index|
        cell = if index == ptd_columns[:values].length
                 row.add_cell(value, type: :string)
               else
                 row.add_cell(value)
               end
        cell.style = row_styles[index]
      end

      add_account_items(sheet: sheet, item_values: item_values.select { |value| value.item_id == item._id.to_s }, item: item, child_step: child_step + 1) if show_outline_level
    end

    def add_account_items(sheet:, item_values:, item:, child_step:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      item.mapped_item_accounts.each do |item_account|
        business_coa = @business_chart_of_accounts.select { |category| category.chart_of_account_id == item_account.chart_of_account_id }.first
        next if business_coa.nil?

        ptd_columns = ptd_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)
        ytd_columns = ytd_account_column_infos(item_values: item_values, item_account: item_account, style: @right_normal_style)

        row_values = combine_row_sections(ptd: ptd_columns[:values], ytd: ytd_columns[:values], item: item_name(name: business_coa.display_name, child_step: child_step))
        row_styles = combine_row_sections(ptd: ptd_columns[:styles], ytd: ytd_columns[:styles], item: @left_normal_style)
        row_widths = combine_row_sections(ptd: ptd_columns[:widths], ytd: ytd_columns[:widths], item: COA_COLUMN_WIDTH)

        next if row_values_zero?(values: ptd_columns[:values].concat(ytd_columns[:values]).reject { |value| value == '-' })

        row = sheet.add_row(row_values, style: row_styles, widths: row_widths)
        set_outline_level(row: row, level: 1)
      end
    end

    def combine_row_sections(ptd: [], ytd: [], item: '')
      if @main_column_position == LEFT
        [item] + ptd + ytd
      else
        ptd + [item] + ytd
      end
    end

    def add_one_parent_item_for_total(sheet:, item:, report_datas:, child_step: 0) # rubocop:disable Metrics/MethodLength
      item.all_child_items.sort_by(&:order).each do |child_item|
        next if total_zero_row?(item: child_item, report_datas: report_datas, is_total: true)

        if child_item.all_child_items.present?
          if child_item.type_config.present?
            add_one_child_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step)
          else
            sheet.add_row([item_name(name: child_item.name, child_step: child_step)])
          end
          add_one_parent_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step + 1)
        else
          add_one_child_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step)
        end
      end
    end

    def add_one_child_item_for_total(sheet:, item:, report_datas:, is_section: false, child_step: 0)
      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      total_columns = total_column_infos(item: item, report_datas: report_datas, style: values_styles.first)
      sheet.add_row([item_name(name: item.name, child_step: child_step)] + total_columns[:values], style: [values_styles.last] + total_columns[:styles], widths: [COA_COLUMN_WIDTH])

      add_totals_account_items(sheet: sheet, report_datas: report_datas, item: item, child_step: child_step + 1)
    end

    def add_totals_account_items(sheet:, report_datas:, item:, child_step:)
      item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @business_chart_of_accounts.select { |category| category.chart_of_account_id == item_account.chart_of_account_id }.first
        next if business_chart_of_account.nil?

        values_styles = values_styles(item: item, is_section: false)
        total_columns = total_account_column_infos(item: item, report_datas: report_datas, item_account: item_account, style: @right_normal_style)
        next if row_values_zero?(values: total_columns[:values].reject { |value| value == '-' })

        row = sheet.add_row([item_name(name: business_chart_of_account.display_name, child_step: child_step)] + total_columns[:values],
                            style: [values_styles.last] + total_columns[:styles], widths: [COA_COLUMN_WIDTH])
        set_outline_level(row: row, level: 1)
      end
    end

    def total_account_column_infos(item:, report_datas:, item_account:, style:)
      totals_account_column_infos(item: item, report_datas: report_datas, item_account: item_account, style: style)
    end

    def ptd_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_CURRENT, item_values: item_values, item_account: item_account, style: style)
    end

    def ytd_account_column_infos(item_values:, item_account:, style:)
      account_column_infos(column_range: Column::RANGE_YTD, item_values: item_values, item_account: item_account, style: style)
    end

    def item_values_with(item:, item_values:)
      item_values.select { |item_value| item_value.item_id == item._id.to_s }
    end

    def ptd_column_infos(item:, item_values:, style:)
      column_infos(column_range: Column::RANGE_CURRENT, item: item, item_values: item_values, style: style)
    end

    def ytd_column_infos(item:, item_values:, style:)
      column_infos(column_range: Column::RANGE_YTD, item: item, item_values: item_values, style: style)
    end

    def column_infos(column_range:, item:, item_values:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if should_skip_column?(column)

        info = item_column_info(item_values: item_values, item: item, column: column, style: style)
        column_values << info[:value]
        column_widths << info[:width]
        column_styles << info[:style]
      end
      { values: column_values, widths: column_widths, styles: column_styles }
    end

    def totals_account_column_infos(item:, report_datas:, item_account:, style:) # rubocop:disable Metrics/MethodLength
      column_values = []
      column_styles = []
      total_columns = multi_range_total_columns
      item_account_values_params = { from: @start_date, to: @end_date, item_identifier: item.identifier }
      total_item_account_values = AccountValue::ItemAccountValuesQuery.new(report: @report, item_account_values_params: item_account_values_params)
                                                                      .item_account_values(only_actual_column: false)

      report_datas.each_with_index do |report_data, index|
        total_columns.each do |column|
          info = if index.zero?
                   total_item_account_column_info(total_item_account_values: total_item_account_values, item: item, column: column, item_account: item_account, style: style)
                 else
                   item_account_column_info(item_account: item_account, item_values: report_data.item_values.all, item: item, column: column, style: style)
                 end

          column_values << info[:value]
          column_styles << info[:style]
        end
      end
      { values: column_values, styles: column_styles }
    end

    def item_account_column_info(item_account:, item_values:, item:, column:, style:)
      item_value = item_values.find { |value| value.item_id == item._id.to_s and value.column_id == column._id.to_s }
      account_column_info(item_value: item_value, item_account: item_account, style: style)
    end

    def account_column_infos(column_range:, item_values:, item_account:, style:) # rubocop:disable Metrics/MethodLength
      column_widths = []
      column_values = []
      column_styles = []
      @report.columns.where(range: column_range).order_by(order: :asc).each do |column|
        next if should_skip_column?(column)

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
      return budget_column_info(item_value: item_value, style: style, budget_id: @filter['budget']) if column.name.include?('Budget')

      column_info(item_value: item_value, style: style)
    end

    def total_column_infos(item:, report_datas:, style:) # rubocop:disable Metrics/MethodLength
      column_values = []
      column_styles = []
      total_columns = multi_range_total_columns
      report_datas.each do |report_data|
        total_columns.each do |column|
          info = item_column_info(item_values: report_data.item_values.all, item: item, column: column, style: style)
          column_values << info[:value]
          column_styles << info[:style]
        end
      end
      { values: column_values, styles: column_styles }
    end

    def set_outline_level(row:, level:)
      return if level.zero?

      row.outline_level = level
      row.hidden = true
    end

    def multi_range_total_columns
      total_columns = []
      @report.multi_range_columns.each do |column|
        next if should_skip_column?(column)

        total_columns << column
      end
      total_columns
    end
  end
end
