# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StandardMetric, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Fields' do
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:type).of_type(String) }
    it { is_expected.to have_field(:code).of_type(String) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:code) }
  end
end
