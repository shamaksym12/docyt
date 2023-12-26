# frozen_string_literal: true

class StandardMetric
  include Mongoid::Document

  field :name, type: String
  field :type, type: String
  field :code, type: String

  validates :name, presence: true
  validates :type, presence: true
  validates :code, presence: true

  index({ name: 1 }, { unique: true })
end
