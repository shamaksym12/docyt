# frozen_string_literal: true

module ExportExcel
  class ExportBudgetDataService < ExportBaseService
    COLUMNS = ['Budget Line Items', 'Type', 'Accounting code', 'Department', 'Budget Total', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].freeze # rubocop:disable Layout/LineLength

    def call(budget:, start_date:, end_date:, filter:) # rubocop:disable Metrics/MethodLength
      @budget = budget
      @start_date = start_date
      @end_date = end_date
      @params = { filter: filter }
      @all_budget_items = BudgetItemsQuery.new(current_budget: @budget, params: @params).all_budget_items

      fetch_accounting_classes(business_id: @budget.report_service.business_id)

      fetch_business_chart_of_accounts(chart_of_account_ids: @all_budget_items.collect(&:chart_of_account_id), business_id: @budget.report_service.business_id)

      p = Axlsx::Package.new
      wb = p.workbook

      wb.styles do |style|
        @left_bold_style = style.add_style(b: true, alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @right_number_currency_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @right_number_normal_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00')

        fill_work_book(work_book: wb)
      end

      @report_file_path = excel_file_path(report_name_prefix: budget.name, start_date: @start_date, end_date: @end_date)

      p.serialize(@report_file_path)
    end

    private

    def fill_work_book(work_book:)
      work_book.add_worksheet(name: 'Sheet1') do |sheet|
        sheet.add_row(['Budget Name', @budget.name], style: Array.new(2, @left_bold_style))
        sheet.add_row(['Year', @budget.year], style: Array.new(2, @left_bold_style))
        sheet.add_row([''])

        sheet.add_row(COLUMNS, style: Array.new(17, @left_bold_style))

        add_worksheet_metrics(sheet: sheet)

        add_worksheet_chart_accounts(sheet: sheet) if @business_chart_of_accounts.count.positive?
      end
    end

    def add_worksheet_metrics(sheet:) # rubocop:disable Metrics/MethodLength
      sheet.add_row(['METRICS'], style: [@left_bold_style])

      style = Array.new(17) { |i| @right_number_normal_style if i > 3 }

      @all_budget_items.each do |budget_item|
        next unless budget_item.standard_metric_id

        total_amount = 0
        budget_values = Array.new(12, 0)
        unless budget_item.is_blank
          budget_values = budget_item.budget_item_values.collect(&:value)

          budget_item.budget_item_values.each do |budget_item_value|
            total_amount += budget_item_value.value
          end
        end
        sheet.add_row([budget_item.standard_metric.name, '', '', '', total_amount].concat(budget_values), style: style)
      end
    end

    def add_worksheet_chart_accounts(sheet:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      sheet.add_row(['CHART OF ACCOUNTS'], style: [@left_bold_style])

      style = Array.new(17) { |i| @right_number_currency_style if i > 3 }
      types = %i[string string string string]

      @all_budget_items.each do |budget_item|
        chart_of_account = @business_chart_of_accounts.find { |business_chart_of_account| business_chart_of_account.chart_of_account_id == budget_item.chart_of_account_id }

        accounting_class = @accounting_classes.find { |accounting_class_item| accounting_class_item.id == budget_item.accounting_class_id }

        total_amount = 0
        budget_values = Array.new(12, 0)
        if budget_item.budget_item_values.count.positive?
          budget_values = budget_item.budget_item_values.collect(&:value)

          budget_item.budget_item_values.each do |budget_item_value|
            total_amount += budget_item_value.value
          end
        end

        next unless chart_of_account

        display_name_split = chart_of_account.display_name.split(': ')
        accounting_code = display_name_split.count > 1 ? display_name_split[0] : ''
        display_name = display_name_split.count > 1 ? display_name_split[1] : chart_of_account.display_name

        sheet.add_row([display_name, chart_of_account.acc_type_name, accounting_code, accounting_class&.name, total_amount].concat(budget_values), style: style, types: types)
      end
    end
  end
end
