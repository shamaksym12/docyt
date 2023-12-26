# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportData, type: :model do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }
  let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'dependent', slug: 'dependent', name: 'name1') }
  let(:custom_report) do
    Report.create!(report_service: report_service,
                   template_id: 'operators_operating_statement',
                   slug: 'operators_operating_statement',
                   name: 'name2',
                   dependent_template_ids: ['dependent'],
                   missing_transactions_calculation_disabled: false)
  end
  let(:budget) { Budget.create!(report_service: report_service, name: 'budget1', year: 2021, updated_at: Time.zone.now) }
  let(:dependent_report_data) do
    create(:report_data, report: dependent_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY, updated_at: '2021-03-31')
  end
  let(:report_data) do
    create(:report_data, report: custom_report, start_date: '2021-03-01', end_date: '2021-03-31', period_type: ReportData::PERIOD_MONTHLY, budget_ids: [budget.id])
  end
  let(:pl_general_ledger) { Quickbooks::ProfitAndLossGeneralLedger.create!(report_service: report_service, start_date: '2021-03-01', end_date: '2021-03-31') }

  it { is_expected.to be_mongoid_document }
  it { is_expected.to have_index_for(report_id: 1, start_date: 1, end_date: 1) }

  describe 'Associations' do
    it { is_expected.to embed_many(:item_values) }
    it { is_expected.to embed_many(:item_account_values) }
    it { is_expected.to belong_to(:report) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:start_date).of_type(Date) }
    it { is_expected.to have_field(:end_date).of_type(Date) }
    it { is_expected.to have_field(:budget_ids).of_type(Array) }
    it { is_expected.to have_field(:update_state).of_type(String) }
    it { is_expected.to have_field(:update_started_at).of_type(DateTime) }
    it { is_expected.to have_field(:update_finished_at).of_type(DateTime) }
  end

  describe '#unincluded_transactions_count' do
    subject(:unincluded_transactions_count) { report_data.unincluded_transactions_count }

    let(:line_item_detail1) { create(:unincluded_line_item_detail, report: custom_report, transaction_date: '2021-02-27') }
    let(:line_item_detail2) { create(:unincluded_line_item_detail, report: custom_report, transaction_date: '2021-03-01') }
    let(:line_item_detail3) { create(:unincluded_line_item_detail, report: custom_report, transaction_date: '2021-03-15') }
    let(:line_item_detail4) { create(:unincluded_line_item_detail, report: custom_report, transaction_date: '2021-03-31') }
    let(:line_item_detail5) { create(:unincluded_line_item_detail, report: custom_report, transaction_date: '2021-04-01') }

    it 'returns unincluded transactions count' do
      line_item_detail1
      line_item_detail2
      line_item_detail3
      line_item_detail4
      line_item_detail5
      expect(unincluded_transactions_count).to eq(3)
    end
  end

  describe '#recalc_digest!' do
    before do
      allow(DocytServerClient::MetricsServiceApi).to receive(:new).and_return(metrics_service_api_instance)
      allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(value_api_instance)
    end

    let(:metrics_service_response) { Struct.new(:id, :type).new(1, 'metrics_service') }
    let(:metrics_service_api_instance) { instance_double(DocytServerClient::MetricsServiceApi, get_by_business_id: metrics_service_response) }
    let(:value_digest_metric_response) { Struct.new(:digest).new('metric_digest') }
    let(:value_api_instance) { instance_double(MetricsServiceClient::ValueApi, get_digest: value_digest_metric_response) }

    it 'sets other_reports field' do
      dependent_report_data
      report_data.recalc_digest!
      expect(report_data.dependency_digests[ReportDependencies::OtherReports.to_s]).to be_present
    end

    it 'sets quickbooks field' do
      pl_general_ledger
      report_data.recalc_digest!
      expect(report_data.dependency_digests[ReportDependencies::Quickbooks.to_s]).not_to be_nil
    end

    it 'sets budgets field' do
      custom_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      report_data.recalc_digest!
      expect(report_data.dependency_digests[ReportDependencies::Budgets.to_s]).to be_present
    end

    it 'sets metrics field' do
      parent_item = custom_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', totals: true)
      custom_report.items.find_or_create_by!(name: 'name', order: 1, identifier: 'child_item', type_config: { 'name' => Item::TYPE_METRIC }, parent_id: parent_item.id.to_s)
      report_data.recalc_digest!
      expect(report_data.dependency_digests[ReportDependencies::Metrics.to_s]).to be_present
    end
  end
end
