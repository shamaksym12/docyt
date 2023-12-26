# frozen_string_literal: true

require 'rails_helper'

module Quickbooks
  RSpec.describe CachingGeneralLedgersService do
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:common_general_ledger) do
      ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: '2023-01-01', end_date: '2023-01-31')
    end
    let(:caching_general_ledgers_service) { described_class.new(report_service) }

    describe '#get' do
      it 'caches CommonGeneralLedger' do
        common_general_ledger
        allow(Quickbooks::CommonGeneralLedger).to receive(:find_by).and_call_original
        general_ledger = caching_general_ledgers_service.get(type: ::Quickbooks::CommonGeneralLedger, start_date: '2023-01-01'.to_date, end_date: '2023-01-31'.to_date)
        expect(general_ledger).to eq(common_general_ledger)
        expect(Quickbooks::CommonGeneralLedger).to have_received(:find_by).once
      end

      it 'gets cached CommonGeneralLedger' do
        common_general_ledger
        caching_general_ledgers_service.get(type: ::Quickbooks::CommonGeneralLedger, start_date: '2023-01-01'.to_date, end_date: '2023-01-31'.to_date)
        allow(Quickbooks::CommonGeneralLedger).to receive(:find_by).and_call_original
        general_ledger = caching_general_ledgers_service.get(type: ::Quickbooks::CommonGeneralLedger, start_date: '2023-01-01'.to_date, end_date: '2023-01-31'.to_date)
        expect(general_ledger).to eq(common_general_ledger)
        expect(Quickbooks::CommonGeneralLedger).not_to have_received(:find_by)
      end
    end
  end
end
