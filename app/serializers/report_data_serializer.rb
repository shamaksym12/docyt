# frozen_string_literal: true

class ReportDataSerializer < ActiveModel::MongoidSerializer
  include ActionView::Helpers::DateHelper
  attributes :id, :period_type, :start_date, :end_date, :update_state, :error_msg, :updated_at, :updated_time_string, :report_id
  attributes :budget_ids
  attributes :unincluded_transactions_count
  has_many :item_values, each_serializer: ItemValueSerializer

  def start_date
    object.start_date.to_s
  end

  def end_date
    object.end_date.to_s
  end

  def report_id
    object.report.id.to_s
  end

  def updated_time_string
    if object.updated_at.blank?
      nil
    elsif object.updated_at > 7.days.ago.to_date
      "#{time_ago_in_words(object.updated_at).sub('about ', '')} ago"
    else
      object.updated_at.strftime('%m/%d/%Y')
    end
  end

  delegate :unincluded_transactions_count, to: :object
end
