# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Budget, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to belong_to(:report_service) }
    it { is_expected.to have_many(:actual_budget_items) }
    it { is_expected.to have_many(:draft_budget_items) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:year) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:year).of_type(Integer) }
    it { is_expected.to have_field(:total_amount).of_type(Float) }
    it { is_expected.to have_field(:creator_id).of_type(Integer) }
    it { is_expected.to have_field(:created_at).of_type(DateTime) }
  end
end
