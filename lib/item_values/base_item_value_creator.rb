# frozen_string_literal: true

module ItemValues
  class BaseItemValueCreator < BaseItemValueCalculator # rubocop:disable Metrics/ClassLength
    OPERATOR_SUM = 'sum'

    # This method will fill the value for the corresponding item_value
    def initialize( # rubocop:disable Metrics/ParameterLists, Metrics/MethodLength
      report_data:, item:, column:,
      standard_metrics:,
      dependent_report_datas:,
      all_business_chart_of_accounts:,
      accounting_classes:,
      caching_report_datas_service:,
      caching_general_ledgers_service:
    )
      super()
      @report_data = report_data
      @item = item
      @column = column
      @report = report_data.report
      @standard_metrics = standard_metrics
      @dependent_report_datas = dependent_report_datas
      @all_business_chart_of_accounts = all_business_chart_of_accounts
      @accounting_classes = accounting_classes
      @caching_report_datas_service = caching_report_datas_service
      @caching_general_ledgers_service = caching_general_ledgers_service
    end

    def call
      raise 'This will be implemented in inherited class.'
    end

    private

    def actual_value_by_identifier(identifier:, column:) # rubocop:disable Metrics/MethodLength
      if identifier.include?('/')
        item_value = actual_item_value_by_identifier_with_dependency(identifier: identifier, column_type: column.type, column_range: column.range, column_year: column.year)
      else
        item_value = @report_data.item_values.detect { |report_item_value| report_item_value.item_identifier == identifier && report_item_value.column_id == column.id.to_s }
        if item_value.nil?
          item = @report.find_item_by_identifier(identifier: identifier)
          creator_instance = ItemValueCreator.new(
            report_data: @report_data,
            standard_metrics: @standard_metrics,
            dependent_report_datas: @dependent_report_datas,
            all_business_chart_of_accounts: @all_business_chart_of_accounts,
            accounting_classes: @accounting_classes,
            caching_report_datas_service: @caching_report_datas_service,
            caching_general_ledgers_service: @caching_general_ledgers_service
          )
          item_value = creator_instance.call(item: item, column: column)
        end
      end
      item_value
    end

    def actual_item_value_by_identifier_with_dependency(identifier:, column_type:, column_range:, column_year:) # rubocop:disable Metrics/CyclomaticComplexity
      identifier_values = identifier.split('/')
      return nil unless identifier_values.length == 2 && @dependent_report_datas.include?(identifier_values[0])

      dependent_report_data = @dependent_report_datas[identifier_values[0]]
      target_column = dependent_report_data.report.columns.detect { |cl| cl.type == column_type && cl.range == column_range && cl.year == column_year }
      dependent_report_data.item_values.detect { |iv| iv.item_identifier == identifier_values[1] && iv.column_id == target_column.id.to_s }
    end

    def generate_item_value(item:, column:, item_amount: 0.0, budget_values: [])
      item_value = @report_data.item_values.new(
        item_id: item.id.to_s, column_id: column.id.to_s, value: item_amount, item_identifier: item.identifier,
        budget_values: budget_values
      )
      item_value.generate_column_type_with_infos(item: item, column: column)
      item_value
    end

    def create_item_account_value(chart_of_account_id:, accounting_class_id:, name: '', value: 0.0, budget_values: [])
      return if chart_of_account_id.nil?

      item_account_value = @report_data.item_account_values.new(
        item_id: @item.id.to_s, column_id: @column.id.to_s,
        chart_of_account_id: chart_of_account_id, accounting_class_id: accounting_class_id,
        name: name, value: value, budget_values: budget_values
      )
      item_account_value.generate_column_type
      item_account_value
    end

    def item_expression(item:, target_column_type:)
      stats_formula = item.values_config[target_column_type] if item.values_config.present?
      return nil if stats_formula.blank? || stats_formula['value'].blank? || stats_formula['value']['expression'].blank?

      stats_formula['value']['expression']
    end

    def fetch_metrics_service(business_id:)
      metrics_service_api_instance = DocytServerClient::MetricsServiceApi.new
      metrics_service_api_instance.get_by_business_id(business_id)
    end

    def item_account_value_name(business_chart_of_account:, accounting_class:)
      if accounting_class.present?
        "#{accounting_class.name} ▸ #{business_chart_of_account.display_name}"
      else
        business_chart_of_account.display_name
      end
    end

    def copy_account_values(src_item_account_values:)
      if @item.use_derived_mapping?
        copy_account_values_for_derived_mapping(src_item_account_values: src_item_account_values)
      else
        copy_account_values_for_general(src_item_account_values: src_item_account_values)
      end
    end

    def copy_account_values_for_derived_mapping(src_item_account_values:) # rubocop:disable Metrics/MethodLength
      src_item_account_values.each do |src_item_account_value|
        item_account_value = @report_data.item_account_values.detect do |iav|
          iav.item_id == @item.id.to_s && iav.column_id == @column.id.to_s &&
            iav.chart_of_account_id == src_item_account_value.chart_of_account_id && iav.accounting_class_id == src_item_account_value.accounting_class_id
        end
        item_account_value ||= create_item_account_value(
          chart_of_account_id: src_item_account_value.chart_of_account_id,
          accounting_class_id: src_item_account_value.accounting_class_id,
          name: src_item_account_value.name
        )
        item_account_value.value = (item_account_value.value + src_item_account_value.value).round(2)
      end
    end

    def copy_account_values_for_general(src_item_account_values:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength,Metrics/PerceivedComplexity
      @item.mapped_item_accounts.each do |item_account|
        business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
        next if business_chart_of_account.nil?

        accounting_class = @accounting_classes.detect { |ac| ac.id == item_account.accounting_class_id }
        next if item_account.accounting_class_id.present? && accounting_class.nil?

        item_account_values = src_item_account_values.select do |iav|
          iav.chart_of_account_id == item_account.chart_of_account_id && iav.accounting_class_id == item_account.accounting_class_id
        end
        create_item_account_value(
          chart_of_account_id: item_account.chart_of_account_id,
          accounting_class_id: item_account.accounting_class_id,
          name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
          value: item_account_values.map(&:value).sum
        )
      end
    end

    def actual_value_with_arg(arg:)
      column_type = arg['column_type'].presence || Column::TYPE_ACTUAL
      column_year = arg['column_year'].presence || @column.year
      source_column = @report.columns.detect { |cl| cl.type == column_type && cl.range == @column.range && cl.year == column_year }
      if arg['constant'].present?
        Struct.new(:value).new(arg['constant'])
      else
        actual_value_by_identifier(identifier: arg['item_id'], column: source_column)
      end
    end

    def budgets_by_column
      if @column.year == Column::YEAR_PRIOR
        Budget.where(report_service: @report.report_service, year: @report_data.start_date.year - 1)
      else
        Budget.where(report_service: @report.report_service, year: @report_data.start_date.year)
      end
    end

    def budget_item_item_value(budget_item:)
      return 0.0 if budget_item.blank?

      budget_item_values = budget_item.budget_item_values.select do |biv|
        Column::RANGE_YTD == @column.range ? biv.month <= start_date_by_column(@report_data).month : biv.month == start_date_by_column(@report_data).month
      end
      budget_item_values.sum(&:value)
    end

    def budget_actual_item_by_item_account(budget:, item_account:)
      filtered_budget_actual_items(budget: budget).find_by(
        chart_of_account_id: item_account[:chart_of_account_id],
        accounting_class_id: item_account[:accounting_class_id],
        standard_metric_id: item_account[:standard_metric_id]
      )
    end

    def filtered_budget_actual_items(budget:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
      actual_budget_items = budget.actual_budget_items
      general_ledger_options = (@item.type_config || {})[Item::GENERAL_LEDGER_OPTIONS_CONFIG] || {}
      if general_ledger_options[Item::OPTIONS_ONLY_CLASSES].present?
        accounting_class_ids = @accounting_classes.select do |business_accounting_class|
          general_ledger_options[Item::OPTIONS_ONLY_CLASSES].include?(business_accounting_class.external_id)
        end.map(&:id)
        actual_budget_items = actual_budget_items.select { |itm| accounting_class_ids.include?(itm.accounting_class_id) }
      end
      if general_ledger_options[Item::OPTIONS_INCLUDE_ACCOUNT_TYPES].present?
        accepted_qbo_ids = ItemValues::ItemActualsValue::ItemGeneralLedgerActualsValueCreator.filter_chart_of_accounts(type_config: @item.type_config,
                                                                                                                       all_biz_chart_of_accounts: @all_business_chart_of_accounts)
                                                                                             .map(&:qbo_id)
        chart_of_account_ids = @all_business_chart_of_accounts.select do |business_chart_of_account|
          accepted_qbo_ids.include?(business_chart_of_account.qbo_id)
        end.map(&:chart_of_account_id)
        actual_budget_items = actual_budget_items.select { |itm| chart_of_account_ids.include?(itm.chart_of_account_id) }
      end
      actual_budget_items
    end

    # Returns start_date of Quickbooks::GeneralLedger for ReportData & Column
    def start_date_by_column(report_data) # rubocop:disable Metrics/MethodLength
      case @column.year
      when Column::YEAR_PRIOR
        report_data.start_date - 1.year
      when Column::PREVIOUS_PERIOD
        report_data.start_date - 1.month
      else
        if report_data.daily? && @column.range == Column::RANGE_MTD
          report_data.start_date.at_beginning_of_month
        else
          report_data.start_date
        end
      end
    end

    # Returns end_date of Quickbooks::GeneralLedger for ReportData & Column
    def end_date_by_column(report_data)
      report_data ||= @report_data
      case @column.year
      when Column::YEAR_PRIOR
        (report_data.start_date - 1.year).end_of_month
      when Column::PREVIOUS_PERIOD
        (report_data.start_date - 1.month).end_of_month
      else
        report_data.end_date
      end
    end

    def find_budget_value(item_value:, budget:)
      if item_value.nil?
        {}
      else
        item_value.budget_values.detect { |bv| bv[:budget_id] == budget.id.to_s } || {}
      end
    end
  end
end
