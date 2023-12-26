# frozen_string_literal: true

module Quickbooks
  class BalanceSheetAnalyzer < GeneralLedgerAnalyzer
    private

    def analyze_columns(raw_data) # rubocop:disable Metrics/MethodLength
      account_column_index = amount_column_index = nil
      columns = raw_data['Columns']['Column']
      columns.each_with_index do |column, index|
        case column['ColType']
        when 'Account'
          account_column_index = index
        when 'Money'
          amount_column_index = index
        end
      end
      [account_column_index, amount_column_index]
    end

    def analyze_row_for_detail(dst_array:, qbo_data:, column_indexes:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      account_column_index = column_indexes[0]
      return if qbo_data['type'].blank?

      # For Header's ColData. This case is that parent chart_of_account has its value.
      if qbo_data['Header'].present? && qbo_data['Header']['ColData'].present? && qbo_data['Header']['ColData'][account_column_index].present? && qbo_data['Header']['ColData'][account_column_index]['id'].present? # rubocop:disable Layout/LineLength
        create_line_item_detail(dst_array: dst_array, col_data: qbo_data['Header']['ColData'], column_indexes: column_indexes)
      end

      if qbo_data['type'] == QBO_ROW_SECTION && qbo_data['Rows'].present? && qbo_data['Rows']['Row'].present?
        qbo_data['Rows']['Row'].each do |sub_row_data|
          analyze_row_for_detail(dst_array: dst_array, qbo_data: sub_row_data, column_indexes: column_indexes)
        end
      else # For 'Data' row
        col_data = qbo_data['ColData']
        return if col_data.blank?

        create_line_item_detail(dst_array: dst_array, col_data: col_data, column_indexes: column_indexes)
      end
    end

    def create_line_item_detail(dst_array:, col_data:, column_indexes:)
      account_column_index = column_indexes[0]
      amount_column_index = column_indexes[1]
      amount = amount_column_index.present? && col_data[amount_column_index].present? ? col_data[amount_column_index]['value'].to_f : 0.0
      qbo_id = col_data[account_column_index]['id'].presence if account_column_index.present? && col_data[account_column_index].present?
      dst_array << { amount: amount, chart_of_account_qbo_id: qbo_id }
    end
  end
end
