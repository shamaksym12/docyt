# frozen_string_literal: true

module Quickbooks
  class CachingGeneralLedgersService
    def initialize(report_service)
      @report_service = report_service
      @cache = {}
    end

    def get(type:, start_date:, end_date:)
      @cache[type.to_s] ||= {}
      cache_general_ledger(type: type, start_date: start_date, end_date: end_date)
    end

    private

    def cache_general_ledger(type:, start_date:, end_date:)
      pointer_str = start_date.strftime('%m/%d/%Y')
      @cache[type.to_s][pointer_str] ||= type.find_by(
        report_service: @report_service,
        start_date: start_date,
        end_date: end_date
      )
    end
  end
end
