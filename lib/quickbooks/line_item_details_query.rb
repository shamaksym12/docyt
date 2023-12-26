# frozen_string_literal: true

module Quickbooks
  class LineItemDetailsQuery < BaseLineItemDetailsQuery
    TOTAL_TYPE = 'total'
    BEGINNING_BALANCE_TYPE = 'beginning_balance'

    def initialize(report:, item:, params:) # rubocop:disable Lint/MissingSuper
      @params = params
      @report = report
      @item = item
    end

    def by_period(start_date:, end_date:, include_total: false) # rubocop:disable Metrics/MethodLength
      fetch_business_information(@report.report_service)
      general_ledgers = @report.report_service.general_ledgers
                               .where(_type: 'Quickbooks::CommonGeneralLedger')
                               .where(start_date: { '$gte' => start_date }, end_date: { '$lte' => end_date })
                               .all
      line_item_details = []
      general_ledgers.each { |general_ledger| line_item_details += extract_line_item_details(general_ledger: general_ledger) }
      line_item_details = add_beginning_and_total_item(line_item_details: line_item_details, start_date: start_date.to_date) if include_total
      line_item_details = paginate(line_item_details)
      return [] if line_item_details.blank?

      fetch_value_links(business_id: @report.report_service.business_id, line_item_details: line_item_details)
    end

    private

    def extract_line_item_details(general_ledger:)
      line_item_details = general_ledger.line_item_details
      if @params[:chart_of_account_id].present?
        line_item_details = add_condition_for_category(
          line_item_details: line_item_details,
          chart_of_account_id: @params[:chart_of_account_id],
          accounting_class_id: @params[:accounting_class_id]
        )
      end
      filter_by_calculation_type(filtered_line_item_details: line_item_details, original_line_item_details: general_ledger.line_item_details)
    end

    def filter_by_calculation_type(filtered_line_item_details:, original_line_item_details:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      return filtered_line_item_details if @item.type_config.blank?

      case @item.type_config[Item::CALCULATION_TYPE_CONFIG]
      when Item::GENERAL_LEDGER_CALCULATION_TYPE
        return filtered_line_item_details if @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG].blank?

        if @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_INCLUDE_SUBLEDGER_ACCOUNT_TYPES].present?
          filtered_line_item_details = combine_line_item_details_from_general_ledgers(
            original_line_item_details: original_line_item_details,
            filtered_line_item_details: filtered_line_item_details,
            account_types: @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_INCLUDE_SUBLEDGER_ACCOUNT_TYPES]
          )
        elsif @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_EXCLUDE_SUBLEDGER_ACCOUNT_TYPES].present?
          filtered_line_item_details = exclude_line_item_details_from_general_ledgers(
            original_line_item_details: original_line_item_details,
            filtered_line_item_details: filtered_line_item_details,
            account_types: @item.type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_EXCLUDE_SUBLEDGER_ACCOUNT_TYPES]
          )
        end
      end
      ItemValues::ItemActualsValue::ItemGeneralLedgerActualsValueCreator.filter_amounts(filtered_line_item_details, @item.type_config, @all_business_chart_of_accounts)
      filtered_line_item_details
    end

    def add_beginning_and_total_item(line_item_details:, start_date:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      result_line_item_details = []
      if @item.type_config.present? && @item.type_config[Item::CALCULATION_TYPE_CONFIG] == Item::BALANCE_SHEET_CALCULATION_TYPE
        balance_sheet_general_ledger = Quickbooks::BalanceSheetGeneralLedger.find_by(
          report_service: @report.report_service,
          start_date: start_date - 1.month, end_date: start_date - 1.day
        )
        beginning_balance_amount = 0.00
        if balance_sheet_general_ledger.present? && @params[:chart_of_account_id].present?
          business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == @params[:chart_of_account_id].to_i }.first
          previous_line_item_details = balance_sheet_general_ledger.line_item_details&.select { |lid| lid.chart_of_account_qbo_id == business_chart_of_account.qbo_id }
          beginning_balance_amount = previous_line_item_details.sum(&:amount).round(2) || 0.00
        end
        result_line_item_details << LineItemDetail.new(transaction_type: BEGINNING_BALANCE_TYPE, amount: beginning_balance_amount)
      end
      result_line_item_details += line_item_details
      result_line_item_details << LineItemDetail.new(transaction_type: TOTAL_TYPE, amount: result_line_item_details.map(&:amount).sum.round(2) || 0.00)
      result_line_item_details
    end

    def add_condition_for_category(line_item_details:, chart_of_account_id:, accounting_class_id:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == chart_of_account_id.to_i }.first
      line_item_details = line_item_details.select { |line_item_detail| line_item_detail.chart_of_account_qbo_id == business_chart_of_account&.qbo_id }
      return line_item_details if @report.accounting_class_check_disabled

      accounting_class = @accounting_classes.select { |business_accounting_class| business_accounting_class.id == accounting_class_id&.to_i }.first
      line_item_details.select { |line_item_detail| line_item_detail.accounting_class_qbo_id == accounting_class&.external_id }
    end

    def combine_line_item_details_from_general_ledgers(original_line_item_details:, filtered_line_item_details:, account_types:)
      sub_line_item_details = sub_ledger_line_item_details(original_line_item_details: original_line_item_details, account_types: account_types)
      filtered_ledger_qbo_ids = Set.new(filtered_line_item_details.map(&:qbo_id))
      sub_line_item_details.select! do |common_lid|
        filtered_ledger_qbo_ids.include?(common_lid.qbo_id)
      end
      sub_line_item_details
    end

    def exclude_line_item_details_from_general_ledgers(original_line_item_details:, filtered_line_item_details:, account_types:)
      sub_line_item_details = sub_ledger_line_item_details(original_line_item_details: original_line_item_details, account_types: account_types)
      sub_ledger_qbo_ids = Set.new(sub_line_item_details.map(&:qbo_id))
      filtered_line_item_details.reject! do |common_lid|
        sub_ledger_qbo_ids.include?(common_lid.qbo_id)
      end
      filtered_line_item_details
    end

    def sub_ledger_line_item_details(original_line_item_details:, account_types:)
      accounts_qbo_ids = @all_business_chart_of_accounts.select do |biz_account|
        account_types.include?(biz_account.acc_type)
      end.map(&:qbo_id)
      original_line_item_details.select { |lid| accounts_qbo_ids.include?(lid.chart_of_account_qbo_id) }
    end

    def paginate(line_item_details, page_size = ITEM_DETAILS_PER_PAGE)
      page_num = (@params[:page] || 1).to_i
      first_index = (page_num - 1) * page_size
      line_item_details.slice(first_index, page_size)
    end
  end
end
