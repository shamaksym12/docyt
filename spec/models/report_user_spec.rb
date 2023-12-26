# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportUser, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:report) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:user_id) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:user_id).of_type(Integer) }
  end
end
