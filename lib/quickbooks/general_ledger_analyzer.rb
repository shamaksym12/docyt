# frozen_string_literal: true

module Quickbooks
  class GeneralLedgerAnalyzer
    include DocytLib::Helpers::PerformanceHelpers

    QBO_ROW_SECTION = 'Section'
    QBO_ROW_DATA = 'Data'

    class << self
      def analyze(line_item_details_raw_data:)
        new.analyze(line_item_details_raw_data: line_item_details_raw_data)
      end
    end

    def analyze(line_item_details_raw_data:)
      # JSON.parse() support up to 100 depth as a default, but sometimes the depth is greater than 100.
      # We can disable depth checking with :max_nesting => false.
      raw_data = JSON.parse(line_item_details_raw_data, max_nesting: false)
      dst_array = []
      column_indexes = analyze_columns(raw_data)
      return dst_array if raw_data['Rows']['Row'].blank?

      raw_data['Rows']['Row'].each do |row_data|
        analyze_row_for_detail(dst_array: dst_array, qbo_data: row_data, column_indexes: column_indexes)
      end
      dst_array
    end
    apm_method :analyze

    private

    def analyze_columns(raw_data) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      class_column_index = category_column_index = amount_column_index = nil
      date_column_index = txntype_column_index = num_column_index = vend_column_index = memo_column_index = split_column_index = nil
      columns = raw_data['Columns']['Column']
      columns.each_with_index do |column, index|
        case column['ColTitle']
        when 'Class'
          class_column_index = index
        when 'Account'
          category_column_index = index
        when 'Date'
          date_column_index = index
        when 'Transaction Type'
          txntype_column_index = index
        when 'Num'
          num_column_index = index
        when 'Vendor'
          vend_column_index = index
        when 'Memo/Description'
          memo_column_index = index
        when 'Split'
          split_column_index = index
        when 'Amount'
          amount_column_index = index
        end
      end
      [class_column_index, category_column_index, amount_column_index, date_column_index, txntype_column_index,
       num_column_index, vend_column_index, memo_column_index, split_column_index]
    end

    def analyze_row_for_detail(dst_array:, qbo_data:, column_indexes:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      class_column_index = column_indexes[0]
      category_column_index = column_indexes[1]
      amount_column_index = column_indexes[2]
      date_column_index = column_indexes[3]
      txntype_column_index = column_indexes[4]
      num_column_index = column_indexes[5]
      vend_column_index = column_indexes[6]
      memo_column_index = column_indexes[7]
      split_column_index = column_indexes[8]
      if qbo_data['type'] == QBO_ROW_SECTION
        qbo_data['Rows']['Row'].each do |sub_row_data|
          analyze_row_for_detail(dst_array: dst_array, qbo_data: sub_row_data, column_indexes: column_indexes)
        end
      else # For 'Data' row
        col_data = qbo_data['ColData']
        return if col_data[txntype_column_index]['value'].blank?

        accounting_class_qbo_id = col_data[class_column_index]['id'].presence if class_column_index.present?
        accounting_class = col_data[class_column_index]['value'].presence if class_column_index.present?
        dst_array << {
          transaction_date: col_data[date_column_index]['value'],
          transaction_type: col_data[txntype_column_index]['value'],
          transaction_number: col_data[num_column_index]['value'],
          memo: col_data[memo_column_index]['value'],
          vendor: col_data[vend_column_index]['value'],
          split: col_data[split_column_index]['value'],
          amount: col_data[amount_column_index]['value'].to_f,
          accounting_class: accounting_class,
          category: col_data[category_column_index]['value'],
          qbo_id: col_data[txntype_column_index]['id'],
          accounting_class_qbo_id: accounting_class_qbo_id,
          chart_of_account_qbo_id: col_data[category_column_index]['id'].presence,
          vendor_qbo_id: col_data[vend_column_index]['id'].presence
        }
      end
    end
  end
end
