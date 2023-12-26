# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemActualsValueCreator < ItemValues::BaseItemValueCreator
      def call
        creator_instance = creator_class.new(
          report_data: @report_data, item: @item, column: @column,
          standard_metrics: @standard_metrics,
          dependent_report_datas: @dependent_report_datas,
          all_business_chart_of_accounts: @all_business_chart_of_accounts,
          accounting_classes: @accounting_classes,
          caching_report_datas_service: @caching_report_datas_service,
          caching_general_ledgers_service: @caching_general_ledgers_service
        )
        creator_instance.call
      end

      private

      def creator_class # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        if @item.type_config.present? && @item.type_config['name'] == Item::TYPE_REFERENCE
          ItemReferenceActualsValueCreator
          # Below case is same with @item.type_config.present? && @item.type_config['name'] == Item::TYPE_STATS
          # But in Store Manager's Report(UPS report), type_config should be 'quickbooks_ledger', not 'stats'.
          # Because this report has several actual columns.
          # So values_config is used to check the column type for 'stats'.
        elsif @item.values_config.present? && @item.values_config[@column.type].present?
          ItemStatActualsValueCreator
        elsif @item.totals
          ItemTotalActualsValueCreator
        elsif @item.type_config['name'] == Item::TYPE_METRIC
          ItemMetricActualsValueCreator
        elsif @item.type_config['name'] == Item::TYPE_QUICKBOOKS_LEDGER
          ItemGeneralLedgerActualsValueCreator
        end
      end
    end
  end
end
