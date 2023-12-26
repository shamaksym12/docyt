# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Column, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:report) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_inclusion_of(:type).to_allow(Column::TYPES) }
    it { is_expected.to validate_inclusion_of(:range).to_allow(Column::RANGES) }
    it { is_expected.to validate_inclusion_of(:year).to_allow(Column::PERIODS) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:type).of_type(String) }
    it { is_expected.to have_field(:range).of_type(String) }
    it { is_expected.to have_field(:year).of_type(String) }
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:per_metric).of_type(String) }
  end
end
