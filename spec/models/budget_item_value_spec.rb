# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetItemValue, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:budget_item) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:month).of_type(Integer) }
    it { is_expected.to have_field(:value).of_type(Float) }
  end
end
