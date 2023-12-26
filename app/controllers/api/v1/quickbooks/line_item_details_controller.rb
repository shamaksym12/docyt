# frozen_string_literal: true

module Api
  module V1
    module Quickbooks
      class LineItemDetailsController < ApplicationController
        def by_period
          ensure_report_access(report: report, operation: :read)
          line_item_details_query = ::Quickbooks::LineItemDetailsQuery.new(
            report: report,
            item: report.find_item_by_identifier(identifier: query_params[:item_identifier]),
            params: query_params
          )
          line_item_details = line_item_details_query.by_period(start_date: params[:from], end_date: params[:to])
          render status: :ok, json: line_item_details, each_serializer: ::Quickbooks::LineItemDetailSerializer, root: 'line_item_details'
        end

        private

        def query_params
          params.permit(:item_identifier, :chart_of_account_id, :accounting_class_id, :page)
        end
      end
    end
  end
end
