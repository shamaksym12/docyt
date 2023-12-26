# frozen_string_literal: true

module Api
  module V1
    class ItemAccountValuesController < ApplicationController
      def by_range
        ensure_report_access(report: report, operation: :read)
        item_account_values_query = AccountValue::ItemAccountValuesQuery.new(report: report, item_account_values_params: item_account_values_params)
        item_account_values = item_account_values_query.item_account_values
        render status: :ok, json: item_account_values, each_serializer: ::ItemAccountValueSerializer
      end

      def by_item_and_column
        ensure_report_access(report: report_data.report, operation: :read)
        item_account_values = report_data.item_account_values.select do |iav|
          iav.item_id == by_item_and_column_params[:item_id] && iav.column_id == by_item_and_column_params[:column_id]
        end
        render status: :ok, json: item_account_values, each_serializer: ::ItemAccountValueSerializer
      end

      def line_item_details # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        ensure_report_access(report: report_data.report, operation: :read)
        chart_of_account_id = line_item_details_params[:chart_of_account_id].to_i unless line_item_details_params[:chart_of_account_id].nil?
        accounting_class_id = line_item_details_params[:accounting_class_id].to_i unless line_item_details_params[:accounting_class_id].nil?
        item_account_value = report_data.item_account_values.detect do |iav|
          iav.item_id == line_item_details_params[:item_id] && iav.column_id == line_item_details_params[:column_id] &&
            iav.chart_of_account_id == chart_of_account_id && iav.accounting_class_id == accounting_class_id
        end
        if item_account_value.present?
          line_item_details = item_account_value.line_item_details(page: params[:page])
          render status: :ok, json: line_item_details, each_serializer: ::Quickbooks::LineItemDetailSerializer, root: 'line_item_details'
        else
          render status: :unprocessable_entity, json: { errors: I18n.t('item_value_invalid') }
        end
      end

      private

      def report_data
        @report_data ||= ReportData.where(_id: params[:report_data_id]).first
      end

      def item_account_values_params
        params.permit(:from, :to, :item_identifier)
      end

      def by_item_and_column_params
        params.permit(:item_id, :column_id)
      end

      def line_item_details_params
        params.permit(:item_id, :column_id, :chart_of_account_id, :accounting_class_id)
      end
    end
  end
end
