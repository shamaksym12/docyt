# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: item_values
#
#  id                   :string
#  chart_of_account_id  :Integer
#  accounting_class_id  :Integer
#  name                 :string
#  value                :float
#

class ItemAccountValueSerializer < ActiveModel::MongoidSerializer
  attributes :id, :item_id, :column_id, :chart_of_account_id, :accounting_class_id, :name, :value, :budget_values, :column_type
  attributes :report_year, :report_month, :item_name, :value_type, :report_data_id

  def report_year
    current_year = object.report_data.end_date.year
    if column.year == Column::YEAR_CURRENT
      current_year
    else
      current_year - 1
    end
  end

  def report_month
    object.report_data.end_date.month
  end

  def report_data_id
    object.report_data.id.to_s
  end

  delegate :name, to: :item, prefix: true

  def value_type
    if column.range == Column::RANGE_CURRENT
      'Current'
    else
      'YTD'
    end
  end

  private

  def item
    @item ||= object.report_data.report.find_item_by_id(id: object.item_id)
  end

  def column
    @column ||= object.report_data.report.columns.detect { |c| c.id.to_s == object.column_id }
  end
end
