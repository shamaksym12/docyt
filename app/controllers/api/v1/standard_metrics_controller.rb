# frozen_string_literal: true

module Api
  module V1
    class StandardMetricsController < ApplicationController
      def index
        render status: :ok, json: StandardMetric.all, each_serializer: ::StandardMetricSerializer
      end
    end
  end
end
