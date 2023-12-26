# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Report, type: :model do
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) { described_class.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:parent_item1) { report.items.find_or_create_by!(name: 'parent_item1', order: 1, identifier: 'parent_item1') }
  let(:parent_item2) { report.items.find_or_create_by!(name: 'parent_item2', order: 2, identifier: 'parent_item2') }
  let(:child_item1) { report.items.find_or_create_by!(name: 'child_item1', order: 1, identifier: 'child_item1', parent_id: parent_item1.id.to_s) }
  let(:child_item2) do
    report.items.find_or_create_by!(
      name: 'child_item2',
      order: 2,
      identifier: 'child_item2',
      type_config: { 'default_accounts' => [{ 'account_type' => 'acc_type1', 'account_detail_type' => 'sub_type1' }] }, parent_id: parent_item1.id.to_s
    )
  end
  let(:item_account1) { child_item1.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 1) }
  let(:item_account2) { child_item2.item_accounts.find_or_create_by!(chart_of_account_id: 2, accounting_class_id: 1) }
  let(:item_account3) { parent_item2.item_accounts.find_or_create_by!(chart_of_account_id: 1, accounting_class_id: 2) }

  it { is_expected.to be_mongoid_document }
  it { is_expected.to have_index_for(report_service_id: 1, slug: 1) }

  describe 'Associations' do
    it { is_expected.to belong_to(:report_service) }
    it { is_expected.to embed_many(:items) }
    it { is_expected.to embed_many(:columns) }
    it { is_expected.to have_many(:report_datas) }
    it { is_expected.to embed_many(:report_users) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:template_id) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe 'Fields' do
    it { is_expected.to have_field(:template_id).of_type(String) }
    it { is_expected.to have_field(:name).of_type(String) }
    it { is_expected.to have_field(:updated_at).of_type(DateTime) }
    it { is_expected.to have_field(:missing_transactions_calculation_disabled).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:dependent_template_ids).of_type(Array) }
    it { is_expected.to have_field(:update_state).of_type(String) }
    it { is_expected.to have_field(:error_msg).of_type(String) }
    it { is_expected.to have_field(:enabled_budget_compare).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:total_column_visible).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:accounting_class_check_disabled).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:accepted_accounting_class_ids).of_type(Array) }
    it { is_expected.to have_field(:accepted_account_types).of_type(Array) }
    it { is_expected.to have_field(:accepted_chart_of_account_ids).of_type(Array) }
    it { is_expected.to have_field(:enabled_blank_value_for_metric).of_type(Mongoid::Boolean) }
  end

  describe '#all_item_accounts' do
    it 'returns all item accounts' do
      item_account1
      item_account2
      item_account3
      expect(report.all_item_accounts.pluck(:id)).to eq([item_account1.id, item_account2.id, item_account3.id])
    end
  end

  describe '#detect_column' do
    before do
      allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
      allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    end

    let(:user) { Struct.new(:id).new(1) }
    let(:department_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: Report::DEPARTMENT_REPORT, name: 'name1' }, current_user: user).report
    end
    let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
    let(:users_response) { Struct.new(:users).new([user_response]) }
    let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
    let(:last_reconciled_month_data) { Struct.new(:year, :month, :status).new(2021, 1, 'reconciled') }
    let(:business_response) do
      instance_double(
        DocytServerClient::BusinessDetail,
        id: 1, bookkeeping_start_date: (Time.zone.today - 1.month),
        display_name: 'My Business', name: 'My Business',
        last_reconciled_month_data: last_reconciled_month_data
      )
    end
    let(:business_info) { Struct.new(:business).new(business_response) }
    let(:business_chart_of_account) do
      instance_double(DocytServerClient::BusinessChartOfAccount,
                      id: 1, business_id: 105, chart_of_account_id: 1001, qbo_id: '60', display_name: 'name1')
    end
    let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([business_chart_of_account]) }
    let(:accounting_class) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: 105, external_id: '4', name: 'class01', parent_external_id: nil) }
    let(:accounting_class_response) { Struct.new(:accounting_classes).new([accounting_class]) }
    let(:business_cloud_service_authorization) { Struct.new(:id, :uid, :second_token).new(id: 1, uid: '46208160000', second_token: 'qbo_access_token') }
    let(:business_quickbooks_connection_info) { instance_double(DocytServerClient::BusinessQboConnection, cloud_service_authorization: business_cloud_service_authorization) }
    let(:business_api_instance) do
      instance_double(DocytServerClient::BusinessApi,
                      get_business: business_info,
                      get_business_chart_of_accounts: business_chart_of_accounts_response,
                      get_accounting_classes: accounting_class_response,
                      get_qbo_connection: business_quickbooks_connection_info)
    end

    it 'returns all item accounts' do
      expect(department_report.detect_column(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)).not_to be_nil
      expect(department_report.detect_column(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT)).not_to be_nil
    end
  end

  describe '#enabled_default_mapping' do
    it 'returns true if this report is enabled for default mapping' do
      child_item1
      child_item2
      expect(report.enabled_default_mapping).to be_truthy
    end
  end

  describe '#report_template' do
    it 'returns template' do
      expect(report.report_template.id).to eq('owners_operating_statement')
    end
  end

  describe '#monthly_report_datas_for_range' do
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-07-01', end_date: '2023-07-31') }

    it 'returns new report datas' do
      report_data
      report_datas = report.monthly_report_datas_for_range(start_date: '2023-07-01'.to_date, end_date: '2023-08-31'.to_date)
      expect(report_datas.count).to eq(2)
    end
  end
end
