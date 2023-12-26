# frozen_string_literal: true

module Quickbooks
  class BaseLineItemDetailsQuery < BaseService
    ITEM_DETAILS_PER_PAGE = 20

    protected

    def fetch_value_links(business_id:, line_item_details:)
      qbo_ids = line_item_details.pluck(:qbo_id)
      report_service_api_instance = DocytServerClient::ReportServiceApi.new
      links = report_service_api_instance.get_account_value_links({ qbo_ids: qbo_ids }, business_id)
      return line_item_details if links.blank?

      line_item_details.each do |line_item_detail|
        link_info = links.detect { |link| link.qbo_id == line_item_detail[:qbo_id] }
        line_item_detail.link = link_info&.link
      end
      line_item_details
    end
  end
end
