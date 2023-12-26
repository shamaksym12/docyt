# frozen_string_literal: true

require 'roo'
require 'open-uri'
module ImportExcel
  class BudgetImportService < BaseService
    include DocytLib::Utils::DocytInteractor
    include DocytLib::Async::Publisher

    BUDGET_XLSX_COLUMNS = ['Budget Line Items', 'Type', 'Accounting code', 'Department', 'Budget Total', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'].freeze # rubocop:disable Layout/LineLength
    HEADER_ROW = 4
    CHART_OF_ACCOUNTS_LABEL = 'CHART OF ACCOUNTS'
    MONTHS = 12
    BUDGET_LINE_ITEMS_COLUMN = 'Budget Line Items'
    DEPARTMENT_COLUMN = 'Department'
    TYPE_COLUMN = 'Type'
    ACCOUNTING_CODE_COLUMN = 'Accounting code'

    def call(import_budget:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      @import_budget = import_budget
      @imported_data = import_excel

      if @imported_data.count.zero?
        finish_import_budget(import_budget_id: @import_budget.budget.id.to_s, status: 'failed')
        return
      end

      @all_budget_items = BudgetItemsQuery.new(current_budget: @import_budget.budget, params: { filter: {} }).all_budget_items

      format_validation = check_valid_format

      @import_budget.destroy_imported_file

      if format_validation
        @all_budget_items.each_with_index do |all_budget_item, index|
          budget_item_values = budget_item_params(@imported_data[index])
          is_changed = false

          if all_budget_item.budget_item_values.count.zero?
            is_changed = true unless budget_item_values.select { |budget_item_value| budget_item_value[:value].positive? }.count.zero?
          else
            all_budget_item.budget_item_values.each_with_index do |budget_item_value, idx|
              unless budget_item_value.month == budget_item_values[idx][:month] && budget_item_value.value == budget_item_values[idx][:value]
                is_changed = true
                break
              end
            end
          end

          BudgetItemFactory.upsert_item(current_budget: @import_budget.budget, budget_item_params: { id: all_budget_item.id, budget_item_values: budget_item_values }) if is_changed
        end
      end

      finish_import_budget(import_budget_id: @import_budget.budget.id.to_s, status: format_validation ? 'success' : 'failed')
    end

    private

    def check_valid_format # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      fetch_accounting_classes(business_id: @import_budget.budget.report_service.business_id)

      fetch_business_chart_of_accounts(chart_of_account_ids: @all_budget_items.collect(&:chart_of_account_id), business_id: @import_budget.budget.report_service.business_id)

      @all_budget_items.each_with_index do |all_budget_item, index|
        if all_budget_item.standard_metric_id
          check_imported_accounting_code = !@imported_data[index][ACCOUNTING_CODE_COLUMN].nil? && @imported_data[index][ACCOUNTING_CODE_COLUMN] != ''
          check_imported_department = !@imported_data[index][DEPARTMENT_COLUMN].nil? && @imported_data[index][DEPARTMENT_COLUMN] != ''
          check_imported_type = !@imported_data[index][TYPE_COLUMN].nil? && @imported_data[index][TYPE_COLUMN] != ''

          return false if @imported_data[index][BUDGET_LINE_ITEMS_COLUMN] != all_budget_item.standard_metric.name || check_imported_accounting_code || check_imported_department || check_imported_type # rubocop:disable Layout/LineLength
        else
          chart_of_account = @business_chart_of_accounts.find { |business_chart_of_account| business_chart_of_account.chart_of_account_id == all_budget_item.chart_of_account_id }
          accounting_class = @accounting_classes.find { |accounting_class_item| accounting_class_item.id == all_budget_item.accounting_class_id }

          display_name_split = chart_of_account.display_name.split(': ')
          display_name = display_name_split.count > 1 ? display_name_split[1] : chart_of_account.display_name
          accounting_code = display_name_split.count > 1 ? display_name_split[0] : ''
          imported_accounting_code = @imported_data[index][ACCOUNTING_CODE_COLUMN].nil? ? '' : @imported_data[index][ACCOUNTING_CODE_COLUMN].to_s

          return false if @imported_data[index][BUDGET_LINE_ITEMS_COLUMN] != display_name || imported_accounting_code != accounting_code || @imported_data[index][DEPARTMENT_COLUMN] != accounting_class&.name || @imported_data[index][TYPE_COLUMN] != chart_of_account.acc_type_name # rubocop:disable Layout/LineLength
        end

        MONTHS.times do |i|
          value = @imported_data[index][Date::ABBR_MONTHNAMES[i + 1]]

          next if value.nil? || value.is_a?(Numeric)

          return false unless value.sub('$', '').is_a?(Numeric)
        end
      end

      true
    end

    def budget_item_params(imported_budget_item)
      budget_item_params = []

      MONTHS.times do |i|
        value = imported_budget_item[Date::ABBR_MONTHNAMES[i + 1]]
        value = 0 if value.nil?
        value = value.sub('$', '').to_f unless value.is_a?(Numeric)
        budget_item_params.push(month: i + 1, value: value)
      end

      budget_item_params
    end

    def import_excel
      data = Roo::Spreadsheet.open(@import_budget.imported_file_url)

      headers = data.row(HEADER_ROW)

      imported_data = []

      return imported_data unless headers == BUDGET_XLSX_COLUMNS

      data.each_with_index do |row, idx|
        next if idx < HEADER_ROW + 1

        budget_data = [headers, row].transpose.to_h
        imported_data.push(budget_data) unless budget_data[BUDGET_LINE_ITEMS_COLUMN] == CHART_OF_ACCOUNTS_LABEL
      end

      imported_data
    end

    def finish_import_budget(import_budget_id:, status:)
      publish(events.import_budget_finished(import_budget_id: import_budget_id, status: status), faye_channel: "/import_budget-#{import_budget_id}")
    end
  end
end
