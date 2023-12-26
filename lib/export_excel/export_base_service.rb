# frozen_string_literal: true

module ExportExcel
  class ExportBaseService < BaseService # rubocop:disable Metrics/ClassLength
    attr_accessor :report_file_path

    COA_COLUMN_WIDTH = 50
    EXPORT_INDENTATION = 2

    protected

    def generate_axlsx(report_name_prefix:) # rubocop:disable Metrics/MethodLength
      @report_file_path = if @is_daily
                            excel_file_path(report_name_prefix: report_name_prefix, start_date: @current_date, end_date: @current_date)
                          else
                            excel_file_path(report_name_prefix: report_name_prefix, start_date: @start_date, end_date: @end_date)
                          end
      p = Axlsx::Package.new
      p.workbook do |work_book|
        generate_work_book_styles(work_book: work_book)
        fill_work_book(work_book: work_book)
      end
      p.serialize(@report_file_path)
    end

    def excel_file_path(report_name_prefix:, start_date:, end_date:)
      report_folder_location = './tmp/multi_business_report_data_export/'
      FileUtils.mkdir_p(report_folder_location) unless File.directory?(report_folder_location)
      report_name_prefix = report_name_prefix.dup.gsub(/[^0-9A-Za-z]/, '-')
      report_file_path = if start_date + 1.month < end_date
                           report_folder_location + "#{report_name_prefix}-#{start_date.year}-#{start_date.month}-#{end_date.year}-#{end_date.month}.xlsx"
                         else
                           report_folder_location + "#{report_name_prefix}-#{end_date.year}-#{end_date.month}.xlsx"
                         end
      system("rm -rf #{report_file_path}")
      report_file_path
    end

    def generate_work_book_styles(work_book:) # rubocop:disable Metrics/MethodLength
      work_book.styles do |style|
        @left_normal_style = style.add_style(alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @right_normal_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true })
        @normal_actual_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @normal_percentage_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @normal_variance_style = style.add_style(alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00')
        @left_bolden_style = style.add_style(b: true, alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @right_bolden_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true })
        @center_bolden_style = style.add_style(b: true, alignment: { horizontal: :center, vertical: :center, wrap_text: true })
        @bolden_actual_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @bolden_percentage_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @bolden_variance_style = style.add_style(b: true, alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00')
        @top_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] }, alignment: { horizontal: :left, vertical: :center, wrap_text: true })
        @top_actual_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                             alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '$* #,##0.00;$* (#,##0.00);$* 0.00;@')
        @top_percentage_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                                 alignment: { horizontal: :right, vertical: :center, wrap_text: true }, format_code: '#,##0.00%')
        @top_variance_border = style.add_style(b: true, border: { style: :thin, color: 'FF000000', edges: %i[top] },
                                               alignment: { horizontal: :left, vertical: :center, wrap_text: true }, format_code: '#,##')
      end
    end

    def fill_work_book(work_book:) end

    def column_info(item_value:, style:)
      column_type = item_value&.column_type
      column_info_with(value: item_value&.value, column_type: column_type, style: style)
    end

    def budget_column_info(item_value:, style:, budget_id:)
      budget_value = item_value.budget_values.detect { |budget| budget[:budget_id] == budget_id } if item_value&.budget_values
      budget_value ||= { value: nil }
      column_type = item_value&.column_type
      column_info_with(value: budget_value[:value], column_type: column_type, style: style)
    end

    def column_info_with(value:, column_type:, style:) # rubocop:disable Metrics/MethodLength
      column_value = case column_type
                     when Column::TYPE_PERCENTAGE
                       (value ? (value / 100.0) : '-')
                     else
                       (value || '-')
                     end
      column_width = nil
      column_style = case column_type
                     when Column::TYPE_PERCENTAGE
                       percentage_column_style(style: style)
                     when Column::TYPE_VARIANCE
                       variance_column_style(style: style)
                     else
                       actual_column_style(style: style)
                     end

      { value: column_value, width: column_width, style: column_style }
    end

    def option_column_info(item_value:, option_item_value:, column:, style:)
      return { value: '-', width: nil, style: style } unless column.type == Column::TYPE_ACTUAL && item_value && option_item_value

      option_value = option_item_value.value
      value = option_value.abs.positive? ? item_value.value / option_value : 0.0
      column_info_with(value: value, column_type: item_value.column_type, style: style)
    end

    def account_column_info(item_value:, item_account:, style:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      column_type = item_value&.column_type
      return { value: '-', width: nil, style: actual_column_style(style: style) } unless column_type == Column::TYPE_ACTUAL

      if item_value
        account_value = item_value.report_data.item_account_values.detect do |iav|
          iav.item_id == item_value.item_id && iav.column_id == item_value.column_id &&
            iav.chart_of_account_id == item_account.chart_of_account_id && iav.accounting_class_id == item_account.accounting_class_id
        end
      end
      column_value = account_value&.value || '-'
      { value: column_value, width: nil, style: actual_column_style(style: style) }
    end

    def total_item_account_column_info(total_item_account_values:, item:, column:, item_account:, style:)
      account_values = total_item_account_values.select do |iav|
        iav.item_id == item.id.to_s && iav.column_id == column.id.to_s &&
          iav.chart_of_account_id == item_account.chart_of_account_id && iav.accounting_class_id == item_account.accounting_class_id
      end
      column_value = account_values.map(&:value).sum || 0.0
      { value: column_value, width: nil, style: actual_column_style(style: style) }
    end

    def percentage_column_style(style:)
      case style
      when @right_normal_style
        @normal_percentage_style
      when @right_bolden_style
        @bolden_percentage_style
      else
        @top_percentage_border
      end
    end

    def actual_column_style(style:)
      case style
      when @right_normal_style
        @normal_actual_style
      when @right_bolden_style
        @bolden_actual_style
      else
        @top_actual_border
      end
    end

    def variance_column_style(style:)
      case style
      when @right_normal_style
        @normal_variance_style
      when @right_bolden_style
        @bolden_variance_style
      else
        @top_variance_border
      end
    end

    def item_name(name:, child_step:)
      return name if child_step.zero?

      name.indent(child_step * EXPORT_INDENTATION)
    end

    def values_styles(item:, is_section:) # rubocop:disable Metrics/MethodLength
      values_column_style = if is_section
                              @top_border
                            else
                              (item.totals ? @right_bolden_style : @right_normal_style)
                            end
      name_column_style = if is_section
                            @top_border
                          else
                            (item.totals ? @left_bolden_style : @left_normal_style)
                          end
      [values_column_style, name_column_style]
    end

    def zero_row?(item:, item_values:, is_total: false) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
      return false unless @is_zero_rows_hidden
      return false if summary_item_ids.include?(item.id.to_s)

      child_items = item.all_child_items
      if child_items.count.positive?
        child_items.each do |child_item|
          next if zero_row?(item: child_item, item_values: item_values)

          return false
        end
      else
        columns = @report.columns.select { |column| column.range == Column::RANGE_CURRENT || column.range == Column::RANGE_MTD }
        column_ids = []
        columns.each do |column|
          next if should_skip_column?(column)

          if is_total
            column_ids << column.id.to_s if column.year == Column::YEAR_CURRENT
          else
            column_ids << column.id.to_s
          end
        end
        values = item_values.select { |value| value.item_id == item.id.to_s }.select { |value| column_ids.include?(value.column_id) }

        values.each do |value|
          next if value.value.nil? || value.value.round(2).zero?

          return false
        end
      end
      true
    end

    def total_zero_row?(item:, report_datas:, is_total: false)
      return false unless @is_zero_rows_hidden
      return false if summary_item_ids.include?(item.id.to_s)

      report_datas.each do |report_data|
        next if zero_row?(item: item, item_values: report_data.item_values.all, is_total: is_total)

        return false
      end
      true
    end

    def row_values_zero?(values:)
      return false unless @is_zero_rows_hidden

      values.all? { |value| value.round(2).zero? }
    end

    def summary_item_ids
      item_ids = []
      item = @report.root_items.select { |i| i.identifier == Item::SUMMARY_ITEM_ID }.first
      unless item.nil?
        item_ids << item.id.to_s
        item_ids << item.all_child_items.map { |i| i.id.to_s }
      end
      item_ids.flatten
    end

    def should_skip_column?(column)
      return false unless @report.enabled_budget_compare

      return filtered_budget(column) if column.name&.include?('Budget')

      filtered_column(column: column)
    end

    def filtered_budget(column)
      return true if (@filter.nil? || @filter['budget'].nil?) && column.name.include?('Budget')

      false
    end

    def filtered_column(column:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return false if @filter.nil?

      filter_configuration = ConfigurationsQuery.new.configuration(configuration_id: ConfigurationsQuery::REPORT_FILTER_CONFIGURATION)
      filter_configuration[:report_filter].each do |report_filter|
        next if @filter[report_filter['id']]

        report_filter['column_filter'].each do |column_filter|
          return true if column_filter['year'].present? && column.year == column_filter['year']
          return true if column_filter['type'].present? && column.type == column_filter['type']
          return true if column_filter['range'].present? && column.range == column_filter['range']
          return true if column_filter['per_metric'].present? && column.per_metric == column_filter['per_metric']
        end
      end
      false
    end
  end
end
