# frozen_string_literal: true

module ExportExcel
  class ExportDepartmentReportDataService < ExportReportDataService
    def call(report:, start_date:, end_date:, filter:)
      @filter = filter || {}
      super(report: report, start_date: start_date, end_date: end_date, filter: @filter)
    end

    private

    def fill_work_book(work_book:)
      report_datas_params = { from: @start_date, to: @end_date, filter: @filter }
      report_data_query = DepartmentReportDatasQuery.new(report: @report, report_datas_params: report_datas_params, include_total: true)
      monthly_report_datas = report_data_query.department_report_datas
      return if monthly_report_datas.blank?

      add_sheets(work_book: work_book, report_datas: monthly_report_datas)
    end

    def add_sheets(work_book:, report_datas:)
      if report_datas.length > 1
        add_total_sheets(work_book: work_book, report_datas: report_datas)
      elsif report_datas.length == 1
        add_department_monthly_sheet(work_book: work_book, report_data: report_datas[0], name: 'Consolidated')
      end
    end

    def add_total_sheets(work_book:, report_datas:)
      add_total_sheet(work_book: work_book, report_datas: report_datas, name: 'TOTAL')
      report_datas.each_with_index do |report_data, index|
        next if index.zero?

        sheet_name = "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
        add_department_monthly_sheet(work_book: work_book, report_data: report_data, name: sheet_name)
      end
    end

    def add_total_sheet_data(sheet:, report_datas:)
      add_total_sheet_header(sheet: sheet, report_datas: report_datas)
      add_department_report_to_sheet(sheet: sheet, report_datas: report_datas)
    end

    def add_department_monthly_sheet(work_book:, report_data:, name:)
      work_book.add_worksheet(name: name, page_setup: { fit_to_page: true, fit_to_width: 1, fit_to_height: 1, orientation: :landscape }) do |sheet|
        add_department_sheet_header(sheet: sheet, report_data: report_data)
        add_department_report_to_sheet(sheet: sheet, report_datas: [report_data])
        add_note(sheet: sheet)
      end
    end

    def add_department_sheet_header(sheet:, report_data:) # rubocop:disable Metrics/MethodLength
      @blank_monthly_columns = []
      months_column_names = []
      column_widths = []
      months_column_names << ''
      @blank_monthly_columns << ''
      column_widths << COA_COLUMN_WIDTH
      months_column_names << "#{report_data.start_date.strftime('%b')}-#{report_data.start_date.strftime('%y')}"
      @blank_monthly_columns << ''
      column_widths << nil
      sheet.add_row(["Company: #{@business.name}"], style: @left_bolden_style)
      sheet.add_row([@report.name], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(["As of #{@end_date.strftime('%m/%d/%Y')}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row(["Last reconciled on #{@last_reconciled_date&.strftime('%m/%Y')}"], style: @left_bolden_style, widths: column_widths)
      sheet.add_row([])
      sheet.add_row(months_column_names, style: @center_bolden_style, widths: column_widths)
    end

    def add_department_report_to_sheet(sheet:, report_datas:) # rubocop:disable Metrics/MethodLength
      include_item_in_report = @filter['accounting_class_id'].blank?
      @report.root_items.sort_by(&:order).each do |item|
        next if total_zero_row?(item: item, report_datas: report_datas)

        sheet.add_row([])
        if item.all_child_items.present?
          sheet.add_row([item.name] + @blank_monthly_columns, style: @top_border)
          add_one_parent_item_for_total(sheet: sheet, item: item, report_datas: report_datas, child_step: 1, include_in_report: include_item_in_report)
        else
          add_one_child_item_for_total(sheet: sheet, item: item, report_datas: report_datas, is_section: true, include_in_report: include_item_in_report)
        end
      end
    end

    def add_one_parent_item_for_total(sheet:, item:, report_datas:, view_per_option_item: false, child_step: 0, include_in_report: false) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
      item.all_child_items.sort_by(&:order).each do |child_item|
        next if total_zero_row?(item: child_item, report_datas: report_datas, is_total: true)

        include_item_in_report = child_item.item_accounts.where(accounting_class_id: @filter['accounting_class_id']).present? || include_in_report
        if child_item.all_child_items.present?
          if include_item_in_report || child_by_filter?(item: child_item)
            sheet.add_row([item_name(name: child_item.name, child_step: child_step)])
            add_one_parent_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step + 1, include_in_report: include_item_in_report)
          else
            add_one_parent_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas, child_step: child_step, include_in_report: include_item_in_report)
          end
        else
          add_one_child_item_for_total(sheet: sheet, item: child_item, report_datas: report_datas,
                                       view_per_option_item: view_per_option_item, child_step: child_step, include_in_report: include_item_in_report)
        end
      end
    end

    def add_one_child_item_for_total(sheet:, item:, report_datas:, view_per_option_item: false, is_section: false, child_step: 0, include_in_report: false) # rubocop:disable Metrics/ParameterLists, Lint/UnusedMethodArgument
      return unless item.item_accounts.where(accounting_class_id: @filter['accounting_class_id']).present? || include_in_report

      return if item.totals && !item.show

      values_styles = values_styles(item: item, is_section: is_section)
      total_columns = total_column_infos(item: item, report_datas: report_datas, style: values_styles.first)
      sheet.add_row([item_name(name: item.name, child_step: child_step)] + total_columns[:values], style: [values_styles.last] + total_columns[:styles], widths: [COA_COLUMN_WIDTH])
    end

    def child_by_filter?(item:)
      item.all_child_items.each do |child_item|
        return true if child_item.item_accounts.where(accounting_class_id: @filter['accounting_class_id']).present? || child_by_filter?(item: child_item)
      end
      false
    end
  end
end
