# frozen_string_literal: true

module Api
  module V1
    class ItemValuesController < ApplicationController
      def show
        ensure_report_access(report: report_data.report, operation: :read)
        item_value = report_data.item_values.detect { |iv| iv._id.to_s == params[:id] }
        if item_value.present?
          render status: :ok, json: item_value, serializer: ::ItemValueSerializer, root: 'item_value'
        else
          render status: :unprocessable_entity, json: { errors: I18n.t('item_value_invalid') }
        end
      end

      def by_range
        ensure_report_access(report: report, operation: :read)
        item_values_query = ItemValuesQuery.new(report: report, item_values_params: item_values_params)
        item_values = item_values_query.item_values
        if item_values.blank?
          render status: :ok, json: []
        else
          render status: :ok, json: item_values, each_serializer: ::ItemValueSerializer
        end
      end

      private

      def report_data
        @report_data ||= ReportData.where(_id: params[:report_data_id]).first
      end

      def item_values_params
        params.permit(:from, :to, :item_identifier)
      end
    end
  end
end
