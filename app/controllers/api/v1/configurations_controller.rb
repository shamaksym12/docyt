# frozen_string_literal: true

module Api
  module V1
    class ConfigurationsController < ApplicationController
      def index
        render status: :ok, json: ::ConfigurationsQuery.new.all_configurations, root: 'configurations'
      end
    end
  end
end
