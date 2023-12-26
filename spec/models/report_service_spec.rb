# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportService, type: :model do
  it { is_expected.to be_mongoid_document }
  it { is_expected.to have_index_for(service_id: 1) }
  it { is_expected.to have_index_for(business_id: 1) }

  describe 'Associations' do
    it { is_expected.to have_many(:general_ledgers) }
    it { is_expected.to have_many(:budgets) }
    it { is_expected.to have_many(:reports) }
    it { is_expected.to have_one(:report_service_option) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:service_id) }
    it { is_expected.to validate_presence_of(:business_id) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:service_id).of_type(Integer) }
    it { is_expected.to have_field(:business_id).of_type(Integer) }
    it { is_expected.to have_field(:ledgers_imported_at).of_type(DateTime) }
    it { is_expected.to have_field(:updated_at).of_type(DateTime) }
  end

  describe '#has_active_subscription?' do
    let(:billing_service_client) { instance_double(BillingServiceClient::SubscriptionApi, get_by_business_id: internal_subscription_response) }
    let(:subscription_plan_struct) { Struct.new(:name) }
    let(:subscription_struct) { Struct.new(:id, :subscription_plan) }
    let(:subscription_response_struct) { Struct.new(:subscription, :success?) }
    let(:internal_subscription_response) { subscription_response_struct.new(subscription_struct.new(Faker::Number.number(3), subscription_plan_struct.new('basic')), true) }
    let(:failed_billing_service_client) { instance_double(BillingServiceClient::SubscriptionApi, get_by_business_id: failed_subscription_response) }
    let(:failed_subscription_response) { subscription_response_struct.new(nil, true) }
    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { described_class.create!(service_id: service_id, business_id: business_id) }

    it 'returns true if subscription exists' do
      allow(BillingServiceClient::SubscriptionApi).to receive(:new).and_return(billing_service_client)
      expect(report_service).to have_active_subscription
    end

    it 'returns false if subscription does not exist' do
      allow(BillingServiceClient::SubscriptionApi).to receive(:new).and_return(failed_billing_service_client)
      expect(report_service).not_to have_active_subscription
    end
  end
end
