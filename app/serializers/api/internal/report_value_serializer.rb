# frozen_string_literal: true

module Api
  module Internal
    class ReportValueSerializer < ActiveModel::MongoidSerializer
      attributes :date, :amount

      def date
        object[:date]
      end

      def amount
        object[:amount]
      end
    end
  end
end
