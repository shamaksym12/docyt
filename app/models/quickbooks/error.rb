# frozen_string_literal: true

require 'oauth2'
module Quickbooks
  class Error
    AUTHORIZATION_FAILED = '3200'
    INTERNAL_SERVER_ERROR = '3100'
    ERROR_THROTTLE_EXCEEDED = '3001'

    THROTTLING_ERROR = 'Docyt has been making too many requests to Quickbooks. Try to update the report again later.'
    AUTHORIZATION_FAILED_ERROR = 'QuickBooks is disconnected.'
    INTERNAL_SERVER_ERROR_MSG = 'Currently Quickbooks Online is not available. Try to update the report again later.'
    UNKNOWN_ERROR = 'Unknown Error'

    class << self
      def error_message(error:)
        new.error_message(error: error)
      end
    end

    def error_message(error:) # rubocop:disable Metrics/MethodLength
      code = parse_error_code(error: error)
      case code
      when AUTHORIZATION_FAILED
        AUTHORIZATION_FAILED_ERROR
      when INTERNAL_SERVER_ERROR
        INTERNAL_SERVER_ERROR_MSG
      when ERROR_THROTTLE_EXCEEDED
        THROTTLING_ERROR
      else
        UNKNOWN_ERROR
      end
    end

    private

    def parse_error_code(error:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return nil if error.response.parsed.blank?

      fault = error.response.parsed.to_h.transform_keys(&:downcase)['fault']
      fault = fault&.transform_keys(&:downcase)
      return nil unless fault && fault['error'] && fault['error'].first

      fault['error'].first.transform_keys(&:downcase)['code']
    end
  end
end
