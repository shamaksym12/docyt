# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Quickbooks::GeneralLedger, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations' do
    it { is_expected.to belong_to(:report_service) }
    it { is_expected.to embed_many(:line_item_details) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:start_date).of_type(Date) }
    it { is_expected.to have_field(:end_date).of_type(Date) }
  end

  describe '#calculate_digest' do
    let(:report_service) { ReportService.create!(service_id: 132, business_id: 105) }
    let(:general_ledger) { Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2022-08-01', end_date: '2022-08-31') }

    it 'generates digest' do
      digest = general_ledger.calculate_digest
      expect(general_ledger.calculate_digest).to eq(digest)
      general_ledger.line_item_details.create!(transaction_type: 'Bill', qbo_id: '148', chart_of_account_qbo_id: '101', amount: 1.00)
      general_ledger.calculate_digest
      expect(general_ledger.digest).not_to eq(digest)
    end
  end
end
