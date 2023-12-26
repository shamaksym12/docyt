# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportReport do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to belong_to(:report) }
    it { is_expected.to belong_to(:multi_business_report) }
    it { is_expected.to belong_to(:report_service) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:user_id).of_type(Integer) }
    it { is_expected.to have_field(:export_type).of_type(String) }
    it { is_expected.to have_field(:start_date).of_type(Date) }
    it { is_expected.to have_field(:end_date).of_type(Date) }
    it { is_expected.to have_field(:filter).of_type(Hash) }
  end
end
