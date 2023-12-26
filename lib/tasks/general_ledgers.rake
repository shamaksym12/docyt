# frozen_string_literal: true

namespace :general_ledgers do
  desc 'Reset digest for all general ledgers'
  task reset_all_digest: :environment do |_t, _args|
    Quickbooks::GeneralLedger.all.each(&:set_digest)
  end
end
