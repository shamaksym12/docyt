# frozen_string_literal: true

module Api
  module V1
    class ItemAccountsController < ApplicationController
      def create_batch
        ensure_report_access(report: report, operation: :write)
        item_result = ItemAccountFactory.create_batch(current_item: current_item, maps: params[:maps])
        if item_result.success?
          render status: :created, json: current_item.item_accounts, each_serializer: ::ItemAccountSerializer
        else
          render status: :unprocessable_entity, json: { errors: item_result.errors }
        end
      end

      def index
        ensure_report_access(report: report, operation: :read)
        render status: :ok, json: report.all_item_accounts, each_serializer: ::ItemAccountSerializer
      end

      def destroy_batch
        ensure_report_access(report: report, operation: :write)
        item_result = ItemAccountFactory.destroy_batch(item_accounts: item_accounts)
        if item_result.success?
          render status: :ok, json: { success: true }
        else
          render status: :unprocessable_entity, json: { errors: item_result.errors }
        end
      end

      def copy_mapping
        ensure_report_access(report: report, operation: :write)
        report_service = ReportService.find_by(service_id: params[:src_report_service_id])
        src_report = report_service.reports.find_by(slug: params[:template_id])
        ensure_report_access(report: src_report, operation: :write)
        item_result = ItemAccountFactory.copy_mapping(src_report: src_report, target_report: report)
        if item_result.success?
          render status: :ok, json: { success: true }
        else
          render status: :unprocessable_entity, json: { errors: item_result.errors }
        end
      end

      def load_default_mapping
        ensure_report_access(report: report, operation: :write)
        result = ItemAccountFactory.load_default_mapping(report: report)
        if result.success?
          render status: :ok, json: { success: true }
        else
          render status: :unprocessable_entity, json: { errors: result.errors }
        end
      end

      private

      def current_item
        report.find_item_by_id(id: params[:item_id])
      end

      def item_accounts
        current_item.item_accounts.where(_id: { '$in': params[:ids].split(',') })
      end
    end
  end
end
