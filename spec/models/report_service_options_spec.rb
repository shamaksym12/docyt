# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportServiceOptions, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to belong_to(:report_service) }
    it { is_expected.to belong_to(:default_budget) }
  end
end
