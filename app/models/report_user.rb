# frozen_string_literal: true

class ReportUser
  include Mongoid::Document

  field :user_id, type: Integer

  validates :user_id, presence: true

  embedded_in :report, class_name: 'Report'
end
