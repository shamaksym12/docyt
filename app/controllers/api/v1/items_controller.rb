# frozen_string_literal: true

module Api
  module V1
    class ItemsController < ApplicationController
      def update
        ensure_report_access(report: report, operation: :write)
        current_item.update!(name: params[:name])
        render status: :ok, json: current_item, serializer: ::ItemSerializer
      end

      def index
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report.root_items.sort_by(&:order), each_serializer: ::ItemSerializer
      end

      def show
        ensure_report_access(report: report, operation: :read)
        item = report.find_item_by_id(id: params[:id])
        render status: :ok, json: item, serializer: ::ItemSerializer
      end

      def destroy
        ensure_report_access(report: report, operation: :write)
        current_item.destroy!
        render status: :ok, json: { success: true }
      end

      def by_multi_business_report
        ensure_multi_business_report(multi_business_report: multi_business_report)
        render status: :ok, json: multi_business_report.all_items, each_serializer: ::ItemSerializer
      end

      def by_identifier
        ensure_report_access(report: report, operation: :read)
        item = report.find_item_by_identifier(identifier: by_identifier_params[:item_identifier])
        render status: :ok, json: item, serializer: ::ItemSerializer
      end

      private

      def current_item
        report.find_item_by_id(id: (params[:id] || params[:parent_item_id]))
      end

      def multi_business_report
        @multi_business_report ||= MultiBusinessReport.where(_id: params[:multi_business_report_id]).first
      end

      def by_identifier_params
        params.permit(:item_identifier)
      end
    end
  end
end
