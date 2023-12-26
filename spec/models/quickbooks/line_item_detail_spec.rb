# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::LineItemDetail, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to be_embedded_in(:general_ledger) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:amount).of_type(Float) }
    it { is_expected.to have_field(:transaction_date).of_type(String) }
    it { is_expected.to have_field(:transaction_type).of_type(String) }
    it { is_expected.to have_field(:transaction_number).of_type(String) }
    it { is_expected.to have_field(:link).of_type(String) }
    it { is_expected.to have_field(:memo).of_type(String) }
    it { is_expected.to have_field(:vendor).of_type(String) }
    it { is_expected.to have_field(:split).of_type(String) }
    it { is_expected.to have_field(:qbo_id).of_type(String) }
    it { is_expected.to have_field(:category).of_type(String) }
    it { is_expected.to have_field(:accounting_class).of_type(String) }
    it { is_expected.to have_field(:chart_of_account_qbo_id).of_type(String) }
    it { is_expected.to have_field(:accounting_class_qbo_id).of_type(String) }
    it { is_expected.to have_field(:vendor_qbo_id).of_type(String) }
  end
end
