# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: items
#
#  id                   :string
#  user_id              :integer
#

class ReportUserSerializer < ActiveModel::MongoidSerializer
  attributes :id, :user_id
end
