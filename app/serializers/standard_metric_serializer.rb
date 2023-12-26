# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: standard_metrics
#
#  id                   :string
#  name                 :string
#

class StandardMetricSerializer < ActiveModel::MongoidSerializer
  attributes :id, :name
end
