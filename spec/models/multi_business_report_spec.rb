# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiBusinessReport, type: :model do
  let(:multi_business_report) do
    described_class.create!(multi_business_report_service_id: 111, template_id: 'operators_operating_statement',
                            name: 'name1', report_ids: [report.id, report2.id])
  end
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:service_id2) { Faker::Number.number(digits: 11) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:business_id2) { Faker::Number.number(digits: 11) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report_service2) { ReportService.create!(service_id: service_id2, business_id: business_id2) }
  let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'name1') }
  let(:report2) { Report.create!(report_service: report_service2, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'name1') }

  it { is_expected.to be_mongoid_document }

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:multi_business_report_service_id) }
    it { is_expected.to validate_presence_of(:template_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:multi_business_report_service_id).of_type(Integer) }
    it { is_expected.to have_field(:template_id).of_type(String) }
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:report_ids).of_type(Array) }
  end

  describe 'Associations' do
    it { is_expected.to embed_many(:columns) }
  end

  describe '#reports' do
    it 'returns reports' do
      multi_business_report
      expect(multi_business_report.reports.count).to eq(2)
    end
  end

  describe '#businesses' do
    before do
      allow(DocytServerClient::BusinessAdvisorApi).to receive(:new).and_return(business_advisor_api_instance)
      allow(DocytServerClient::BusinessesApi).to receive(:new).and_return(businesses_api_instance)
    end

    let(:business_advisor_response) { OpenStruct.new(id: 1, business_id: business_id) }
    let(:business_advisors) { OpenStruct.new(business_advisors: [business_advisor_response]) }
    let(:business_advisor_api_instance) { instance_double(DocytServerClient::BusinessAdvisorApi, get_by_ids: business_advisors) }
    let(:business_response) do
      instance_double(DocytServerClient::Business, id: business_id, bookkeeping_start_date: (Time.zone.today - 1.month))
    end
    let(:businesses_response) { OpenStruct.new(businesses: [business_response]) }
    let(:businesses_api_instance) do
      instance_double(DocytServerClient::BusinessesApi, get_by_ids: businesses_response)
    end

    it 'returns businesses' do
      multi_business_report
      expect(multi_business_report.businesses.count).to eq(1)
    end
  end

  describe '#business_ids' do
    it 'returns business ids' do
      multi_business_report
      expect(multi_business_report.business_ids).to eq([business_id, business_id2])
    end
  end

  describe '#all_items' do
    before do
      report.items.create!(name: 'name1', order: 1, identifier: 'name1')
      report.items.create!(name: 'name2', order: 2, identifier: 'name2')
      report2.items.create!(name: 'name3', order: 1, identifier: 'name3')
    end

    it 'returns all items of first report' do
      expect(multi_business_report.all_items.length).to eq(2)
    end

    it 'merges and returns all items across all reports' do
      report.items.update_all(type_config: { # rubocop:disable Rails/SkipsModelValidations
                                'name' => 'quickbooks_ledger',
                                'general_ledger_options' => {
                                  'only_vendors' => ['59'],
                                  'include_account_types' => [
                                    'Expense',
                                    'Cost Of Goods Sold',
                                    'Other Expense',
                                    'Income',
                                    'Other Income'
                                  ]
                                }
                              })
      expect(multi_business_report.all_items.length).to eq(3)
    end
  end

  describe '#update_daily_report_datas' do
    it 'updates all report datas' do
      expect do
        multi_business_report.update_daily_report_datas(current_date: '2020-03-13')
      end.to change { DocytLib.async.event_queue.size }.by(2)
      expect(DocytLib.async.event_queue.events.last.priority).to eq(ReportFactory::MANUAL_UPDATE_PRIORITY)
    end
  end
end
