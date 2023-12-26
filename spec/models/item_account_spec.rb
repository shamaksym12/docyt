# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemAccount, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:item) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:chart_of_account_id).of_type(Integer) }
    it { is_expected.to have_field(:accounting_class_id).of_type(Integer) }
  end
end
