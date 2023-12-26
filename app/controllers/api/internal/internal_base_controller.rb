# frozen_string_literal: true

module Api
  module Internal
    class InternalBaseController < ApplicationController
      include DocytLib::Helpers::ControllerHelpers
      ensure_service_permission
    end
  end
end
