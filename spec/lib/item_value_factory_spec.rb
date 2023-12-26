# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ItemValueFactory do
  before do
    allow(DocytServerClient::MetricsServiceApi).to receive(:new).and_return(metrics_service_api_instance)
    allow(MetricsServiceClient::ValueApi).to receive(:new).and_return(metrics_service_value_api_instance)
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
  end

  let(:metrics_service_response) { Struct.new(:id, :type).new(1, 'metrics_service') }
  let(:metrics_service_api_instance) { instance_double(DocytServerClient::MetricsServiceApi, get_by_business_id: metrics_service_response) }
  let(:metrics_service_category_value_response) { Struct.new(:value).new(30.0) }
  let(:metrics_service_value_api_instance) { instance_double(MetricsServiceClient::ValueApi, get_metric_value: metrics_service_category_value_response) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }

  let(:metric_start_date) { Time.zone.today - 10.days }
  let(:business_metric_response) do
    instance_double(MetricsServiceClient::BusinessMetricResponse,
                    id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                    data_type: 'currency', start_date: metric_start_date, input_data_mode: 'Integration')
  end
  let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
  let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'owners_operating_statement', name: 'owners' }, current_user: user).report
  end
  let(:reference_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'operators_operating_statement', name: 'operator' }, current_user: user).report
  end
  let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31') }
  let(:reference_report_data) { reference_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31') }
  let(:common_general_ledger) do
    ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date,
                                              end_date: report_data.end_date)
  end

  let(:department_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT, name: 'report') }
  let(:department_column) { department_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:department_report_data) { department_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31') }

  let(:business_chart_of_accounts) do
    JSON.parse(
      file_fixture('business_chart_of_accounts.json').read,
      object_class: Struct.new(:id, :business_id, :chart_of_account_id, :qbo_id, :qbo_error, :display_name, :parent_id, :mapped_class_ids, :acc_type)
    )
  end
  let(:accounting_classes) { JSON.parse(file_fixture('accounting_classes.json').read, object_class: Struct.new(:id, :business_id, :name, :external_id, :parent_external_id)) }

  let(:standard_metric1) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Available Rooms', code: 'rooms_available') }
  let(:standard_metric2) { StandardMetric.create!(name: 'Rooms Sold', type: 'Sold Rooms', code: 'rooms_sold') }
  let(:standard_metrics) { [standard_metric1, standard_metric2] }
  let(:budget_item_values) do
    [
      { month: 1, value: 10.0 },
      { month: 2, value: 10.0 },
      { month: 3, value: 10.0 },
      { month: 4, value: 10.0 },
      { month: 5, value: 10.0 },
      { month: 6, value: 10.0 },
      { month: 7, value: 10.0 },
      { month: 8, value: 10.0 },
      { month: 9, value: 10.0 },
      { month: 10, value: 10.0 },
      { month: 11, value: 10.0 },
      { month: 12, value: 10.0 }
    ]
  end
  let(:budget1) { Budget.create!(report_service: report_service, name: 'budget1', year: 2021) }
  let(:budget2) { Budget.create!(report_service: report_service, name: 'budget2', year: 2021) }
  let(:actual_budget_items) do
    ActualBudgetItem.create!(
      budget_id: budget1.id, chart_of_account_id: nil, accounting_class_id: nil,
      standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values
    )
    ActualBudgetItem.create!(
      budget_id: budget1.id, chart_of_account_id: nil, accounting_class_id: nil,
      standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values
    )
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 279_243, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 364_182, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 11_874, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 592_376, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 11_884, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget1.id, chart_of_account_id: 11_942, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(
      budget_id: budget2.id, chart_of_account_id: nil, accounting_class_id: nil,
      standard_metric_id: standard_metric1.id.to_s, budget_item_values: budget_item_values
    )
    ActualBudgetItem.create!(
      budget_id: budget2.id, chart_of_account_id: nil, accounting_class_id: nil,
      standard_metric_id: standard_metric2.id.to_s, budget_item_values: budget_item_values
    )
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 279_243, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 364_182, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 11_874, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 592_376, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 11_884, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
    ActualBudgetItem.create!(budget_id: budget2.id, chart_of_account_id: 11_942, accounting_class_id: nil, standard_metric_id: nil, budget_item_values: budget_item_values)
  end
  let(:budgets) { [budget1, budget2] }

  describe '#generate_batch' do
    before do
      budgets
      actual_budget_items
      standard_metrics
      items = JSON.parse(file_fixture('report_items.json').read)
      report.update!(items: items)
      common_general_ledger_body = file_fixture('profit_and_loss_general_ledger.json').read
      common_general_ledger.update!(JSON.parse(common_general_ledger_body))

      described_class.generate_batch(report_data: report_data, dependent_report_datas: {},
                                     all_business_chart_of_accounts: business_chart_of_accounts,
                                     accounting_classes: accounting_classes)
    end

    it 'creates metric item_values for TYPE_ACTUAL columns' do
      current_actual_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_available', column_id: current_actual_column.id)
      item_value2 = report_data.item_values.find_by(item_identifier: 'rooms_sold', column_id: current_actual_column.id)
      expect(item_value1.value).to eq(30.0)
      expect(item_value2.value).to eq(30.0)
    end

    it 'creates reference item_values for TYPE_ACTUAL columns' do
      report_data.save!
      described_class.generate_batch(report_data: reference_report_data, dependent_report_datas: { 'owners_operating_statement' => report_data },
                                     all_business_chart_of_accounts: business_chart_of_accounts, accounting_classes: accounting_classes)
      current_actual_column = reference_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = reference_report_data.item_values.find_by(item_identifier: 'rooms_available', column_id: current_actual_column.id)
      item_value2 = reference_report_data.item_values.find_by(item_identifier: 'rooms_sold', column_id: current_actual_column.id)
      item_value3 = reference_report_data.item_values.find_by(item_identifier: 'occupancy_percent', column_id: current_actual_column.id)
      expect(item_value1.value).to eq(30.0)
      expect(item_value2.value).to eq(30.0)
      expect(item_value3.value).to eq(100.0)
    end

    it 'creates qbo_general_ledger item_values for TYPE_ACTUAL columns' do
      current_actual_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_revenue', column_id: current_actual_column.id)
      item_value2 = report_data.item_values.find_by(item_identifier: 'other_revenue', column_id: current_actual_column.id)
      item_value3 = report_data.item_values.find_by(item_identifier: 'info_telecom', column_id: current_actual_column.id)
      item_value4 = report_data.item_values.find_by(item_identifier: 'interest', column_id: current_actual_column.id)
      expect(item_value1.value).to eq(16.25)
      expect(item_value2.value).to eq(3.0)
      expect(item_value3.value).to eq(-192.96)
      expect(item_value4.value).to eq(4.2)
    end

    it 'creates stats item_values for TYPE_ACTUAL columns' do
      current_actual_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'occupancy_percent', column_id: current_actual_column.id)
      item_value2 = report_data.item_values.find_by(item_identifier: 'rooms_income', column_id: current_actual_column.id)
      item_value3 = report_data.item_values.find_by(item_identifier: 'other_income', column_id: current_actual_column.id)
      expect(item_value1.value).to eq(100.0)
      expect(item_value2.value).to eq(16.25)
      expect(item_value3.value).to eq(3.0)
    end

    it 'does not create item_values for metric items and TYPE_PERCENTAGE columns' do
      current_percentage_column = report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_available', column_id: current_percentage_column.id)
      expect(item_value1).to be_nil
    end

    it 'does not create item_values for reference items and TYPE_PERCENTAGE columns' do
      described_class.generate_batch(report_data: reference_report_data, dependent_report_datas: { 'owners_operating_statement' => report_data },
                                     all_business_chart_of_accounts: business_chart_of_accounts, accounting_classes: accounting_classes)
      reference_report_data.reload
      current_percentage_column = reference_report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = reference_report_data.item_values.find_by(item_identifier: 'rooms_available', column_id: current_percentage_column.id)
      item_value2 = reference_report_data.item_values.find_by(item_identifier: 'rooms_sold', column_id: current_percentage_column.id)
      item_value3 = reference_report_data.item_values.find_by(item_identifier: 'occupancy_percent', column_id: current_percentage_column.id)
      expect(item_value1).to be_nil
      expect(item_value2).to be_nil
      expect(item_value3).to be_nil
    end

    it 'creates item_values for TYPE_PERCENTAGE columns' do # rubocop:disable RSpec/MultipleExpectations
      current_percentage_column = report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_revenue', column_id: current_percentage_column.id)
      item_value2 = report_data.item_values.find_by(item_identifier: 'other_revenue', column_id: current_percentage_column.id)
      item_value4 = report_data.item_values.find_by(item_identifier: 'rooms_expenses', column_id: current_percentage_column.id)
      item_value5 = report_data.item_values.find_by(item_identifier: 'rooms_income', column_id: current_percentage_column.id)
      item_value6 = report_data.item_values.find_by(item_identifier: 'info_telecom', column_id: current_percentage_column.id)
      item_value7 = report_data.item_values.find_by(item_identifier: 'gross_profit', column_id: current_percentage_column.id)
      item_value8 = report_data.item_values.find_by(item_identifier: 'interest', column_id: current_percentage_column.id)
      item_value9 = report_data.item_values.find_by(item_identifier: 'income_bef_taxes', column_id: current_percentage_column.id)
      expect(item_value1.value).to eq(100.0)
      expect(item_value2.value).to eq(100.0)
      expect(item_value4.value).to eq(0.0)
      expect(item_value5.value).to eq(100.0)
      expect(item_value6.value).to eq(100.0)
      expect(item_value7.value).to eq(0.0)
      expect(item_value8.value).to eq(100.0)
      expect(item_value9.value).to eq(0.0)
    end

    it 'creates item_values for TYPE_VARIANCE columns' do
      current_item = report.find_item_by_identifier(identifier: 'info_telecom')
      current_ly_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR)
      current_ly_value = report_data.item_values.find_by!(item_identifier: 'info_telecom', item_id: current_item.id, column_id: current_ly_column.id)
      current_ly_value.update!(value: 10.0)
      current_variance_column = report.columns.find_by(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT)
      report_data.item_values.where(item_identifier: 'info_telecom', column_id: current_variance_column.id).destroy_all
      ItemValues::ItemValueCreator.new(
        report_data: report_data,
        standard_metrics: nil,
        dependent_report_datas: nil,
        all_business_chart_of_accounts: business_chart_of_accounts,
        accounting_classes: accounting_classes,
        caching_report_datas_service: ItemValues::CachingReportDatasService.new(report_service),
        caching_general_ledgers_service: Quickbooks::CachingGeneralLedgersService.new(report_service)
      ).call(item: current_item, column: current_variance_column)
      item_value1 = report_data.item_values.find_by(item_identifier: 'info_telecom', column_id: current_variance_column.id)
      expect(item_value1.value).to eq(-202.96)
    end

    it 'creates budget_values for TYPE_BUDGET_ACTUAL columns' do
      current_budget_actual_column = report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_available', column_id: current_budget_actual_column.id)
      item_value2 = report_data.item_values.find_by(item_identifier: 'rooms_revenue', column_id: current_budget_actual_column.id)
      expect(item_value1.budget_values[0][:value]).to eq(10.0)
      expect(item_value1.budget_values[1][:value]).to eq(10.0)
      expect(item_value2.budget_values[0][:value]).to eq(60.0)
    end

    it 'creates budget_values for TYPE_BUDGET_PERCENTAGE columns' do
      current_budget_percentage_column = report.columns.find_by(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_revenue', column_id: current_budget_percentage_column.id)
      expect(item_value1.budget_values[0][:value]).to eq(100.0)
    end

    it 'creates budget_values for TYPE_BUDGET_VARIANCE columns' do
      current_budget_variance_column = report.columns.find_by(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT)
      item_value1 = report_data.item_values.find_by(item_identifier: 'rooms_revenue', column_id: current_budget_variance_column.id)
      expect(item_value1.budget_values[0][:value]).to eq(-43.75)
    end

    it 'fills budget_ids' do
      expect(report_data.budget_ids).to eq([budget1.id.to_s, budget2.id.to_s])
    end

    it 'creates balanceSheet item_values for TYPE_ACTUAL columns' do
      current_actual_column = report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT)
      item_value = report_data.item_values.find_by(item_identifier: 'admin_general', column_id: current_actual_column.id)
      expect(item_value.value).to eq(0.0)
    end
  end

  describe '#department generate_batch' do
    before do
      department_column
      department_report_items = JSON.parse(file_fixture('department_report_items.json').read)
      department_report.update!(items: department_report_items)
    end

    it 'creates item_values for department report' do
      general_ledger_body = file_fixture('department_general_ledger.json').read
      common_general_ledger.update!(JSON.parse(general_ledger_body))
      described_class.generate_batch(report_data: department_report_data, dependent_report_datas: {},
                                     all_business_chart_of_accounts: business_chart_of_accounts, accounting_classes: accounting_classes)
      item_value1 = department_report_data.item_values.find_by(item_identifier: 'expenses_5000000000000145595', column_id: department_column.id)
      item_value2 = department_report_data.item_values.find_by(item_identifier: 'profit_5000000000000145595', column_id: department_column.id)

      expect(item_value1.value).to eq(-192.96)
      expect(item_value2.value).to eq(192.96)
    end
  end

  xdescribe '#test generating report data' do
    before do
      budgets
      actual_budget_items
      standard_metrics
      items = JSON.parse(file_fixture('report_items.json').read)
      report.update!(items: items)
      common_general_ledger_body = file_fixture('profit_and_loss_general_ledger.json').read
      report.items.each do |item|
        item.item_accounts.find_or_create_by!(chart_of_account_id: 1001)
        item.item_accounts.find_or_create_by!(chart_of_account_id: 1002)
        item.item_accounts.find_or_create_by!(chart_of_account_id: 1003)
      end
      parsed_ledger_body = JSON.parse(common_general_ledger_body)
      (1..12).each do |month|
        general_ledger = ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: Date.new(2021, month, 1), end_date: Date.new(2021, month, -1))
        general_ledger.update!(parsed_ledger_body)
      end
    end

    let(:dec_report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-12-01', end_date: '2021-12-31') }

    it 'calculates the period' do
      start_at = Time.zone.now
      described_class.generate_batch(report_data: dec_report_data, dependent_report_datas: {},
                                     all_business_chart_of_accounts: business_chart_of_accounts, accounting_classes: accounting_classes)
      end_at = Time.zone.now
      puts "It generated the data for #{end_at - start_at} seconds"
      expect(end_at - start_at - 5).to be_negative
    end
  end
end
