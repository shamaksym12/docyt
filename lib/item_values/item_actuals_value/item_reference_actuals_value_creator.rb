# frozen_string_literal: true

module ItemValues
  module ItemActualsValue
    class ItemReferenceActualsValueCreator < ItemValues::BaseItemValueCreator
      def call
        generate_from_reference
      end

      private

      def generate_from_reference
        reference_item_value = dependent_report_item_value
        item_amount = reference_item_value&.value || 0.0
        item_value = generate_item_value(item: @item, column: @column, item_amount: item_amount)
        item_value.column_type = reference_item_value&.column_type
        item_value
      end

      def dependent_report_item_value # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
        column_range = @item.type_config['src_column_range'].presence || @column.range
        identifier = @item.type_config['reference']
        identifier_values = identifier.split('/')
        return nil unless identifier_values.length == 2

        dependent_report = @report_data.report.dependent_reports.detect { |report| report.template_id == identifier_values[0] }
        target_column = dependent_report.columns.detect { |cl| cl.type == @column.type && cl.range == column_range && cl.year == @column.year }
        if target_column.present?
          dependent_report_data = @caching_report_datas_service.get(report: dependent_report, start_date: @report_data.start_date, end_date: @report_data.end_date)
        else
          target_column = dependent_report.columns.detect { |cl| cl.type == @column.type && cl.range == column_range && cl.year == Column::YEAR_CURRENT }
          start_date = @report_data.start_date - date_delta
          end_date = @report_data.end_date - date_delta
          end_date = end_date.at_end_of_month unless @report_data.daily?
          dependent_report_data = @caching_report_datas_service.get(report: dependent_report, start_date: start_date, end_date: end_date)
        end
        return nil if dependent_report_data.blank?

        dependent_report_data.item_values.detect { |iv| iv.item_identifier == identifier_values[1] && iv.column_id == target_column.id.to_s }
      end

      def date_delta
        return 1.year if @column.year == Column::YEAR_PRIOR
        return 0 if @column.year != Column::PREVIOUS_PERIOD

        case @report_data.period_type
        when ReportData::PERIOD_MONTHLY
          1.month
        when ReportData::PERIOD_DAILY
          1.day
        else
          0
        end
      end
    end
  end
end
