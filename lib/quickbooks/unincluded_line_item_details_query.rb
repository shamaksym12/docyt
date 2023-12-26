# frozen_string_literal: true

module Quickbooks
  class UnincludedLineItemDetailsQuery < BaseLineItemDetailsQuery
    def initialize(report:, params:) # rubocop:disable Lint/MissingSuper
      @params = params
      @report = report
    end

    def by_period(start_date:, end_date:)
      query = Quickbooks::UnincludedLineItemDetail.where(report: @report).where(transaction_date: { '$gte' => start_date, '$lte' => end_date })
      if @params[:chart_of_account_id].present?
        query = add_condition_for_category(
          query: query,
          chart_of_account_id: @params[:chart_of_account_id],
          accounting_class_id: @params[:accounting_class_id]
        )
      end
      line_item_details = paginate(query).to_a
      fetch_value_links(business_id: @report.report_service.business_id, line_item_details: line_item_details)
    end

    private

    def add_condition_for_category(query:, chart_of_account_id:, accounting_class_id:)
      fetch_business_information(@report.report_service)
      business_chart_of_account = @all_business_chart_of_accounts.select { |category| category.chart_of_account_id == chart_of_account_id }.first
      query = query.where(chart_of_account_qbo_id: business_chart_of_account&.qbo_id)
      return query if accounting_class_id.blank?

      accounting_class = @accounting_classes.select { |business_accounting_class| business_accounting_class.id == accounting_class_id }.first
      query.where(accounting_class_qbo_id: accounting_class&.external_id)
    end

    def paginate(query, page_size = ITEM_DETAILS_PER_PAGE)
      page_num = @params[:page] || 1
      query.page(page_num).per(page_size)
    end
  end
end
