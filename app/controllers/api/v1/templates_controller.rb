# frozen_string_literal: true

module Api
  module V1
    class TemplatesController < ApplicationController
      def index
        query = ::TemplatesQuery.new(query_params)
        render status: :ok, json: query.templates, root: 'templates'
      end

      def all_templates
        render status: :ok, json: ::TemplatesQuery.new.all_templates, root: 'templates'
      end

      private

      def query_params
        params.permit(:standard_category_id, standard_category_ids: [])
      end
    end
  end
end
