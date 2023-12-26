# frozen_string_literal: true

module Api
  module V1
    class ReportUsersController < ApplicationController
      def create
        ensure_report_access(report: report, operation: :write)
        ReportFactory.grant_access(report: report, user_id: params[:user_id])
        render status: :created, json: { success: true }
      end

      def destroy
        ensure_report_access(report: report, operation: :write)
        ReportFactory.revoke_access(report: report, user_id: params[:id])
        render status: :ok, json: { success: true }
      end
    end
  end
end
