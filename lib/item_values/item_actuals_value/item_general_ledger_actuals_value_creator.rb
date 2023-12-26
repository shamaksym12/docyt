# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemGeneralLedgerActualsValueCreator < ItemValues::BaseItemValueCreator # rubocop:disable Metrics/ClassLength
      def call
        generate_from_general_ledger
      end

      def self.filter_amounts(line_items, type_config, all_biz_chart_of_accounts) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        general_ledger_options = type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG] || {}
        amount_type = general_ledger_options[Item::AMOUNT_TYPE]

        line_items.select! { |lid| lid.amount >= 0.00 } if Item::AMOUNT_TYPE_DEBIT == amount_type

        line_items.select! { |lid| lid.amount < 0.00 } if Item::AMOUNT_TYPE_CREDIT == amount_type

        line_items.select! { |lid| general_ledger_options[Item::OPTIONS_ONLY_VENDORS].include?(lid.vendor_qbo_id) } if general_ledger_options[Item::OPTIONS_ONLY_VENDORS].present?
        if general_ledger_options[Item::OPTIONS_ONLY_CLASSES].present?
          line_items.select! { |lid| general_ledger_options[Item::OPTIONS_ONLY_CLASSES].include?(lid.accounting_class_qbo_id) }
        end

        return line_items if general_ledger_options[Item::OPTIONS_INCLUDE_ACCOUNT_TYPES].blank?

        accepted_accounts_qbo_ids = filter_chart_of_accounts(type_config: type_config, all_biz_chart_of_accounts: all_biz_chart_of_accounts).map(&:qbo_id)
        line_items.select! { |lid| accepted_accounts_qbo_ids.include?(lid.chart_of_account_qbo_id) }
      end

      def self.filter_chart_of_accounts(type_config:, all_biz_chart_of_accounts:)
        general_ledger_options = type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG] || {}
        return [] if general_ledger_options[Item::OPTIONS_INCLUDE_ACCOUNT_TYPES].blank?

        all_biz_chart_of_accounts.select do |biz_account|
          general_ledger_options[Item::OPTIONS_INCLUDE_ACCOUNT_TYPES].include?(biz_account.acc_type)
        end
      end

      private

      def generate_from_general_ledger
        item_value = generate_item_value(item: @item, column: @column, item_amount: 0.0)

        item_value_amount = if @item.use_derived_mapping?
                              generate_item_value_with_derived_accounts
                            else
                              generate_item_value_with_mapped_accounts
                            end
        value = @item.negative ? -item_value_amount : item_value_amount
        item_value.value = value.round(2)
        item_value
      end

      def generate_item_value_with_mapped_accounts
        item_value_amount = 0.0
        @item.mapped_item_accounts.each do |item_account|
          business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
          next if business_chart_of_account.nil?

          accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.id == item_account.accounting_class_id }
          next if item_account.accounting_class_id.present? && accounting_class.nil?

          item_value_amount += generate_item_account_value(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
        end
        item_value_amount
      end

      def generate_item_value_with_derived_accounts # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        item_value_amount = 0.0
        line_item_details = combined_line_item_details.flatten
        self.class.filter_amounts(line_item_details, @item.type_config, @all_business_chart_of_accounts)
        all_category_qbo_ids = line_item_details.map(&:chart_of_account_qbo_id).uniq
        all_category_qbo_ids.each do |chart_of_account_qbo_id|
          business_chart_of_account = @all_business_chart_of_accounts.detect { |category| category.qbo_id == chart_of_account_qbo_id }
          next if business_chart_of_account.nil?

          category_line_item_details = line_item_details.select do |lid|
            lid.chart_of_account_qbo_id == chart_of_account_qbo_id
          end
          all_class_qbo_ids = category_line_item_details.map(&:accounting_class_qbo_id).uniq
          all_class_qbo_ids.each do |accounting_class_qbo_id|
            accounting_class = @accounting_classes.detect { |business_accounting_class| business_accounting_class.external_id == accounting_class_qbo_id }
            item_value_amount += generate_item_account_value(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class)
          end
        end
        item_value_amount
      end

      def generate_item_account_value(business_chart_of_account:, accounting_class:)
        item_account_value_amount = calculate_item_account_value_for_report_data(report_data: @report_data,
                                                                                 business_chart_of_account: business_chart_of_account,
                                                                                 accounting_class: accounting_class)
        create_item_account_value(
          chart_of_account_id: business_chart_of_account.chart_of_account_id, accounting_class_id: accounting_class&.id,
          name: item_account_value_name(business_chart_of_account: business_chart_of_account, accounting_class: accounting_class),
          value: item_account_value_amount.round(2)
        )
        item_account_value_amount
      end

      # This method can be redefined in child class
      def calculate_item_account_value_for_report_data(report_data:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/MethodLength
        case @item.type_config['name']
        when Item::TYPE_QUICKBOOKS_LEDGER
          calculation_date_range = DateRangeHelper.item_value_calculation_date_range(report_data: report_data, column: @column, item: @item)
          qbo_balance_sheet = @caching_general_ledgers_service.get(
            type: Quickbooks::BalanceSheetGeneralLedger,
            start_date: calculation_date_range.first, end_date: calculation_date_range.last
          )
          qbo_general_ledgers = general_ledgers_from_calculation_date_range(calculation_date_range: calculation_date_range)
          case @item.type_config[Item::CALCULATION_TYPE_CONFIG]
          when Item::BALANCE_SHEET_CALCULATION_TYPE
            calculate_item_account_value_with_balance_sheet(
              qbo_balance_sheet: qbo_balance_sheet,
              business_chart_of_account: business_chart_of_account, accounting_class: accounting_class
            )
          else
            calculate_item_account_value_with_general_ledgers(
              qbo_general_ledgers: qbo_general_ledgers,
              calculation_date_range: calculation_date_range,
              business_chart_of_account: business_chart_of_account, accounting_class: accounting_class
            )
          end
        end
      end

      def calculate_item_account_value_with_balance_sheet(qbo_balance_sheet:, business_chart_of_account:, accounting_class:) # rubocop:disable Metrics/CyclomaticComplexity
        return 0.00 if qbo_balance_sheet.blank?

        qbo_line_item_details = qbo_balance_sheet.line_item_details.select do |lid|
          lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id
        end
        qbo_line_item_details.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id } unless @report.accounting_class_check_disabled
        qbo_line_item_details.sum(&:amount) || 0.00
      end

      def calculate_item_account_value_with_general_ledgers(qbo_general_ledgers:, business_chart_of_account:, accounting_class:, calculation_date_range:)
        item_account_value_amount = 0.00
        qbo_general_ledgers.each do |qbo_general_ledger|
          item_account_value_amount += calculate_item_account_value_with_general_ledger(
            qbo_general_ledger: qbo_general_ledger,
            calculation_date_range: calculation_date_range,
            business_chart_of_account: business_chart_of_account, accounting_class: accounting_class
          )
        end
        item_account_value_amount
      end

      def calculate_item_account_value_with_general_ledger(qbo_general_ledger:, business_chart_of_account:, accounting_class:, calculation_date_range:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        qbo_line_item_details = qbo_general_ledger.line_item_details.select do |lid|
          lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id
        end
        qbo_line_item_details.select! { |lid| lid.accounting_class_qbo_id == accounting_class&.external_id } unless @report.accounting_class_check_disabled
        if @report_data.daily?
          qbo_line_item_details.select! do |lid|
            transaction_date = lid.transaction_date.to_date
            (transaction_date >= calculation_date_range.first) && (transaction_date <= calculation_date_range.last)
          end
        end
        self.class.filter_amounts(qbo_line_item_details, @item.type_config, @all_business_chart_of_accounts)
        if @item.type_config.dig(Item::GENERAL_LEDGER_OPTIONS_CONFIG, Item::OPTIONS_INCLUDE_SUBLEDGER_ACCOUNT_TYPES).present?
          qbo_line_item_details = include_line_item_details(qbo_line_item_details)
        elsif @item.type_config.dig(Item::GENERAL_LEDGER_OPTIONS_CONFIG, Item::OPTIONS_EXCLUDE_SUBLEDGER_ACCOUNT_TYPES).present?
          qbo_line_item_details = exclude_line_item_details(qbo_line_item_details)
        end
        qbo_line_item_details.sum(&:amount) || 0.00
      end

      def exclude_line_item_details(line_item_details)
        excluding_line_item_details = line_item_details_from_account_types(
          line_item_details: line_item_details,
          account_types: @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_EXCLUDE_SUBLEDGER_ACCOUNT_TYPES]
        )
        excluding_line_item_detail_qbo_ids = Set.new(excluding_line_item_details.map(&:qbo_id))
        line_item_details.reject! do |line_item_detail|
          excluding_line_item_detail_qbo_ids.include?(line_item_detail.qbo_id)
        end
        line_item_details
      end

      def include_line_item_details(line_item_details)
        including_line_item_details = line_item_details_from_account_types(
          line_item_details: line_item_details,
          account_types: @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_INCLUDE_SUBLEDGER_ACCOUNT_TYPES]
        )
        including_line_item_detail_qbo_ids = Set.new(including_line_item_details.map(&:qbo_id))
        line_item_details.select! do |line_item_detail|
          including_line_item_detail_qbo_ids.include?(line_item_detail.qbo_id)
        end
        line_item_details
      end

      # This is used to calculate derived mapped items.
      def combined_line_item_details
        calculation_date_range = DateRangeHelper.item_value_calculation_date_range(report_data: @report_data, column: @column, item: @item)
        qbo_general_ledgers = general_ledgers_from_calculation_date_range(calculation_date_range: calculation_date_range)
        qbo_general_ledgers.map(&:line_item_details)
      end

      def line_item_details_from_account_types(line_item_details:, account_types:)
        accepted_accounts_qbo_ids = @all_business_chart_of_accounts.select do |biz_account|
          account_types.include?(biz_account.acc_type)
        end.map(&:qbo_id)
        line_item_details.select { |lid| accepted_accounts_qbo_ids.include?(lid.chart_of_account_qbo_id) }
      end

      # This method returns all monthly CommonGeneralLedger objects to calculate this item actual value for the column.
      def general_ledgers_from_calculation_date_range(calculation_date_range:) # rubocop:disable Metrics/MethodLength
        qbo_general_ledgers = []
        start_date = calculation_date_range.first.at_beginning_of_month
        while start_date <= calculation_date_range.last
          qbo_general_ledger = @caching_general_ledgers_service.get(
            type: Quickbooks::CommonGeneralLedger,
            start_date: start_date, end_date: start_date.at_end_of_month
          )
          qbo_general_ledgers << qbo_general_ledger if qbo_general_ledger.present?
          start_date += 1.month
        end
        qbo_general_ledgers
      end
    end
  end
end
