# frozen_string_literal: true

module ExportExcel
  class ExportMultiBusinessReportDataService < ExportBaseService # rubocop:disable Metrics/ClassLength
    attr_accessor :report_file_path

    def call(multi_business_report:, start_date:, end_date:, filter: {}) # rubocop:disable Metrics/MethodLength
      @multi_business_report = multi_business_report
      return unless multi_business_report.reports.length.positive?

      @report = multi_business_report.reports[0]
      @start_date = start_date
      @end_date = end_date
      @is_daily = start_date == end_date
      @current_date = @start_date
      @actual_column_id = @report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)&.id
      @percentage_column_id = @report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)&.id
      @is_zero_rows_hidden = if filter.nil? || filter['is_zero_rows_hidden'].nil?
                               false
                             else
                               filter['is_zero_rows_hidden']
                             end
      generate_axlsx(report_name_prefix: multi_business_report.name)
    end

    private

    def fill_work_book(work_book:)
      report_datas_params = { from: @start_date, to: @end_date, current: @current_date, is_daily: @is_daily }
      report_data_query = MultiBusinessReportDatasQuery.new(multi_business_report: @multi_business_report, report_datas_params: report_datas_params)
      multi_business_report_datas = report_data_query.report_datas
      return if multi_business_report_datas.blank?

      get_config_info(report_datas: multi_business_report_datas)
      add_sheet(work_book: work_book, report_datas: multi_business_report_datas)
    end

    def add_sheet(work_book:, report_datas:)
      work_book.add_worksheet(name: 'Aggregate', page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_sheet_header(sheet: sheet, report_datas: report_datas)
        add_report_to_sheet(sheet: sheet, report_datas: report_datas)
      end
    end

    def add_sheet_header(sheet:, report_datas:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      @blank_header_columns = []
      business_column_names = []
      ptd_column_names = ['']
      column_widths = []
      business_column_names << '' << 'Aggregate'
      ptd_column_names += @multi_business_report.columns.pluck(:name)
      column_widths << COA_COLUMN_WIDTH
      column_count = @multi_business_report.columns.length
      (1..column_count).each do |column_index|
        @blank_header_columns << ''
        business_column_names << '' if column_index != column_count
      end
      sheet.add_row([@multi_business_report.name], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(["As of #{@end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row([])
      sheet.merge_cells("#{Axlsx.cell_r(1, 3)}:#{Axlsx.cell_r(column_count, 3)}")
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        business = get_business(report_data.report.report_service)
        business_column_names << business.name
        ptd_column_names += @multi_business_report.columns.pluck(:name)
        sheet.merge_cells("#{Axlsx.cell_r(index * column_count + 1, 3)}:#{Axlsx.cell_r((index + 1) * column_count, 3)}")
        (1..column_count).each do |column_index|
          @blank_header_columns << ''
          column_widths << nil
          business_column_names << '' if column_index != column_count
        end
      end
      sheet.add_row(business_column_names, style: @center_bolden_style, widths: column_widths)
      sheet.add_row(ptd_column_names, style: @center_bolden_style, widths: column_widths)
    end

    def add_report_to_sheet(sheet:, report_datas:)
      @multi_business_report.all_items.each do |item|
        next if total_zero_row?(item: item, report_datas: report_datas, is_total: true)

        sheet.add_row([])
        if item.all_child_items.present?
          sheet.add_row([item.name] + @blank_header_columns, style: @top_border)
          add_one_parent_item(sheet: sheet, item: item, report_datas: report_datas, child_step: 1)
        else
          add_one_child_item(sheet: sheet, item: item, report_datas: report_datas, is_section: true)
        end
      end
    end

    def add_one_parent_item(sheet:, item:, report_datas:, child_step:)
      item.all_child_items.sort_by(&:order).each do |child_item|
        next if total_zero_row?(item: child_item, report_datas: report_datas, is_total: true)

        if child_item.all_child_items.present?
          sheet.add_row([item_name(name: child_item.name, child_step: child_step)])
          add_one_parent_item(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step + 1)
        else
          add_one_child_item(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step)
        end
      end
    end

    def add_one_child_item(sheet:, item:, report_datas:, is_section: false, child_step: 0)
      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      columns = column_infos(item: item, report_datas: report_datas, style: values_styles.first)
      sheet.add_row([item_name(name: item.name, child_step: child_step)] + columns[:values], style: [values_styles.last] + columns[:styles], widths: [COA_COLUMN_WIDTH])
    end

    def column_infos(item:, report_datas:, style:)  # rubocop:disable Metrics/MethodLength
      column_values = []
      column_styles = []
      report_datas.each do |report_data|
        @multi_business_report.columns.each do |column|
          target_column = get_column(report_data_id: report_data.id.to_s, column_type: column[:type])
          item_value = report_data.item_values.find_by(item_identifier: item.identifier, column_id: target_column.id.to_s)
          info = column_info(item_value: item_value, style: style)
          column_values << info[:value]
          column_styles << info[:style]
        end
      end
      { values: column_values, styles: column_styles }
    end

    def get_config_info(report_datas:)
      @actual_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_ACTUAL)
      @percentage_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_PERCENTAGE)
      @gross_actual_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_GROSS_ACTUAL)
      @gross_percentage_columns = all_columns(report_datas: report_datas, column_type: Column::TYPE_GROSS_PERCENTAGE)
    end

    def get_column(report_data_id:, column_type:)
      case column_type
      when Column::TYPE_ACTUAL
        @actual_columns[report_data_id]
      when Column::TYPE_PERCENTAGE
        @percentage_columns[report_data_id]
      when Column::TYPE_GROSS_ACTUAL
        @gross_actual_columns[report_data_id]
      when Column::TYPE_GROSS_PERCENTAGE
        @gross_percentage_columns[report_data_id]
      end
    end

    def all_columns(report_datas:, column_type:)
      columns = {}
      report_datas.each do |report_data|
        column = report_data.report.columns.find_by(type: column_type, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
        next if column.nil?

        columns[report_data.id.to_s] = column
      end
      columns
    end
  end
end
