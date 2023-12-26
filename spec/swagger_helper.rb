# frozen_string_literal: true

require 'rails_helper'
require 'docyt_lib/test_support/swagger_helper'

RSpec.configure do |config|
  config.swagger_docs['v1/swagger.yaml'][:info][:title] = 'reports_service API'
  config.swagger_docs['v1/swagger.yaml'][:components][:schemas].merge!(
    {
      #
      # Models and objects
      #
      report_value: {
        type: :object,
        properties: {
          date: { type: :string },
          amount: { type: :float }
        },
        required: ['date']
      }
    }
  )
end
