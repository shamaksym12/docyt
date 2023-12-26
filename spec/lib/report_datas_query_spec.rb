# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReportDatasQuery do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    allow(MetricsServiceClient::BusinessMetricApi).to receive(:new).and_return(business_metric_api_instance)
    report_data3
    item_value1
    item_value2
    item_value3
    item_value4
    item_value5
    item_value6
    item_value7
    item_value8
    item_value11
    item_value12
    item_value13
    item_value14
    item_value15
    item_value16
    item_value17
    item_value18
    item_value19
    item_value20
    item_value21
    item_value22
    item_value23
    item_value24
    item_value25
    item_value29
    item_value30
    item_value31
    item_value32
    item_value33
    item_value34
    item_value35
    item_value36
    item_value37
  end

  let(:metric_start_date) { Time.zone.today - 10.days }
  let(:business_metric_response) do
    instance_double(MetricsServiceClient::BusinessMetricResponse,
                    id: 'metric_id', name: 'Available Rooms', frequency: 'Daily', code: 'Available Rooms',
                    data_type: 'integer', start_date: metric_start_date, input_data_mode: 'Integration')
  end
  let(:business_metric_data_response) { Struct.new(:business_metrics).new([business_metric_response]) }
  let(:business_metric_api_instance) { instance_double(MetricsServiceClient::BusinessMetricApi, fetch_business_metrics: business_metric_data_response) }

  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:business_id) { Faker::Number.number(digits: 10) }
  let(:service_id) { Faker::Number.number(digits: 10) }
  let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
  let(:owners_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'owners_operating_statement', name: 'name1' }, current_user: user).report
  end
  let(:report_data1) { owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31', budget_ids: [1, 2, 3]) }
  let(:report_data2) { owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30', budget_ids: [1, 2, 3]) }
  let(:daily_report_data) { owners_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-02-01', end_date: '2021-02-01') }
  let(:item1) { owners_report.find_item_by_identifier(identifier: 'total_operating_revenue') }
  let(:item2) { owners_report.find_item_by_identifier(identifier: 'other_revenue') }
  let(:rooms_available_item) { owners_report.find_item_by_identifier(identifier: 'rooms_available') }
  let(:rooms_sold_item) { owners_report.find_item_by_identifier(identifier: 'rooms_sold') }
  let(:occupancy_percent_item) { owners_report.find_item_by_identifier(identifier: 'occupancy_percent') }
  let(:rooms_revenue_item) { owners_report.find_item_by_identifier(identifier: 'rooms_revenue') }
  let(:adr_item) { owners_report.find_item_by_identifier(identifier: 'adr') }
  let(:rev_par_item) { owners_report.find_item_by_identifier(identifier: 'rev_par') }
  let(:column) { owners_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:budget_actual_column) { owners_report.columns.find_by(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item1.identifier) }
  let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: item2.identifier) }
  let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: item1.identifier) }
  let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: item2.identifier) }
  let(:item_value_for_budget1) do
    report_data1.item_values.create!(item_id: item1._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item1.identifier,
                                     budget_values: [{ budget_id: 1, value: 10 }, { budget_id: 2, value: 20 }, { budget_id: 3, value: 30 }])
  end
  let(:item_value_for_budget2) do
    report_data1.item_values.create!(item_id: item2._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item2.identifier,
                                     budget_values: [{ budget_id: 1, value: 20 }, { budget_id: 2, value: 30 }, { budget_id: 3, value: 40 }])
  end
  let(:item_value_for_budget3) do
    report_data2.item_values.create!(item_id: item1._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item1.identifier,
                                     budget_values: [{ budget_id: 1, value: 30 }, { budget_id: 2, value: 40 }, { budget_id: 3, value: 50 }])
  end
  let(:item_value_for_budget4) do
    report_data2.item_values.create!(item_id: item2._id.to_s, column_id: budget_actual_column._id.to_s, item_identifier: item2.identifier,
                                     budget_values: [{ budget_id: 1, value: 40 }, { budget_id: 2, value: 50 }, { budget_id: 3, value: 60 }])
  end
  let(:daily_item_value1) do
    daily_report_data.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0,
                                          item_identifier: item1.identifier)
  end
  let(:daily_item_value2) do
    daily_report_data.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0,
                                          item_identifier: item2.identifier)
  end
  let(:rooms_available_item_value1) do
    report_data1.item_values.create!(item_id: rooms_available_item._id.to_s, column_id: column._id.to_s,
                                     value: 10.0, item_identifier: rooms_available_item.identifier)
  end
  let(:rooms_sold_item_value1) do
    report_data1.item_values.create!(item_id: rooms_sold_item._id.to_s, column_id: column._id.to_s,
                                     value: 5.0, item_identifier: rooms_sold_item.identifier)
  end
  let(:rooms_revenue_item_value1) do
    report_data1.item_values.create!(item_id: rooms_revenue_item._id.to_s, column_id: column._id.to_s,
                                     value: 3.0, item_identifier: rooms_revenue_item.identifier)
  end
  let(:rooms_available_item_value2) do
    report_data2.item_values.create!(item_id: rooms_available_item._id.to_s, column_id: column._id.to_s,
                                     value: 10.0, item_identifier: rooms_available_item.identifier)
  end
  let(:rooms_sold_item_value2) do
    report_data2.item_values.create!(item_id: rooms_sold_item._id.to_s, column_id: column._id.to_s,
                                     value: 3.0, item_identifier: rooms_sold_item.identifier)
  end
  let(:rooms_revenue_item_value2) do
    report_data2.item_values.create!(item_id: rooms_revenue_item._id.to_s, column_id: column._id.to_s,
                                     value: 3.0, item_identifier: rooms_revenue_item.identifier)
  end
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }

  let(:store_managers_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'store_managers_report', name: "Store Manager's Report" }, current_user: user).report
  end
  let(:report_data3) { store_managers_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:item3) { store_managers_report.find_item_by_identifier(identifier: 'retail_shipping_supplies') }
  let(:item4) { store_managers_report.find_item_by_identifier(identifier: 'packaging_materials') }
  let(:actual_column) { store_managers_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:gross_actual_column) { store_managers_report.columns.find_by(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value5) { report_data3.item_values.create!(item_id: item3._id.to_s, column_id: actual_column._id.to_s, value: 35.0, item_identifier: item3.identifier) }
  let(:item_value6) { report_data3.item_values.create!(item_id: item3._id.to_s, column_id: gross_actual_column._id.to_s, value: 30.0, item_identifier: item3.identifier) }
  let(:item_value7) { report_data3.item_values.create!(item_id: item4._id.to_s, column_id: actual_column._id.to_s, value: 45.0, item_identifier: item4.identifier) }
  let(:item_value8) { report_data3.item_values.create!(item_id: item4._id.to_s, column_id: gross_actual_column._id.to_s, value: 40.0, item_identifier: item4.identifier) }

  let(:report_data4) { owners_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-03-05', end_date: '2021-03-05') }
  let(:item_value9) { report_data4.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.5, item_identifier: item1.identifier) }
  let(:item_value10) { report_data4.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.5, item_identifier: item2.identifier) }

  let(:executive_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'executive_operating_statement', name: 'Executive Operating Statement' }, current_user: user).report
  end
  let(:executive_actual_column) { executive_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:executive_item) { executive_report.find_item_by_identifier(identifier: 'monthly_recurring_revenue') }
  let(:executive_report_data1) { executive_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:executive_report_data2) { executive_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:executive_item_value1) do
    executive_report_data1.item_values.create!(item_id: executive_item._id.to_s, column_id: executive_actual_column._id.to_s,
                                               value: 20.0, item_identifier: executive_item.identifier)
  end
  let(:executive_item_value2) do
    executive_report_data2.item_values.create!(item_id: executive_item._id.to_s, column_id: executive_actual_column._id.to_s,
                                               value: 30.0, item_identifier: executive_item.identifier)
  end

  let(:cash_flow_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'cash_flow', name: 'cash_flow_report' }, current_user: user).report
  end
  let(:report_data5) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
  let(:report_data6) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
  let(:report_data7) { cash_flow_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
  let(:item5) { cash_flow_report.find_item_by_identifier(identifier: 'cash_temporary_cash_investments_beginning_of_period') }
  let(:item6) { cash_flow_report.find_item_by_identifier(identifier: 'distribution_owners_partners') }
  let(:item7) { cash_flow_report.find_item_by_identifier(identifier: 'cash_temporary_cash_investments_end_period') }
  let(:column1) { cash_flow_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value11) { report_data5.item_values.create!(item_id: item5._id.to_s, column_id: column1._id.to_s, value: 3.0, item_identifier: item5.identifier) }
  let(:item_value12) { report_data6.item_values.create!(item_id: item5._id.to_s, column_id: column1._id.to_s, value: 4.0, item_identifier: item5.identifier) }
  let(:item_value13) { report_data7.item_values.create!(item_id: item5._id.to_s, column_id: column1._id.to_s, value: 5.0, item_identifier: item5.identifier) }
  let(:item_value14) { report_data5.item_values.create!(item_id: item6._id.to_s, column_id: column1._id.to_s, value: 6.0, item_identifier: item6.identifier) }
  let(:item_value15) { report_data6.item_values.create!(item_id: item6._id.to_s, column_id: column1._id.to_s, value: 7.0, item_identifier: item6.identifier) }
  let(:item_value16) { report_data7.item_values.create!(item_id: item6._id.to_s, column_id: column1._id.to_s, value: 8.0, item_identifier: item6.identifier) }
  let(:item_value17) { report_data5.item_values.create!(item_id: item7._id.to_s, column_id: column1._id.to_s, value: 6.0, item_identifier: item7.identifier) }
  let(:item_value18) { report_data6.item_values.create!(item_id: item7._id.to_s, column_id: column1._id.to_s, value: 7.0, item_identifier: item7.identifier) }
  let(:item_value19) { report_data7.item_values.create!(item_id: item7._id.to_s, column_id: column1._id.to_s, value: 8.0, item_identifier: item7.identifier) }

  let(:revenue_accounting_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'revenue_accounting_report', name: 'revenue_accounting_report' }, current_user: user).report
  end
  let(:report_data8) { revenue_accounting_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
  let(:report_data9) { revenue_accounting_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
  let(:report_data10) { revenue_accounting_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
  let(:item8) { revenue_accounting_report.find_item_by_identifier(identifier: 'total_beginning_outstanding_revenue') }
  let(:item9) { revenue_accounting_report.find_item_by_identifier(identifier: 'beginning_accounts_receivables') }
  let(:item10) { revenue_accounting_report.find_item_by_identifier(identifier: 'ending_accounts_receivables') }
  let(:item14) { revenue_accounting_report.find_item_by_identifier(identifier: 'additional_accounts_receivables') }
  let(:column2) { revenue_accounting_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value20) { report_data8.item_values.create!(item_id: item14._id.to_s, column_id: column2._id.to_s, value: 3.0, item_identifier: item14.identifier) }
  let(:item_value21) { report_data9.item_values.create!(item_id: item14._id.to_s, column_id: column2._id.to_s, value: 4.0, item_identifier: item14.identifier) }
  let(:item_value22) { report_data10.item_values.create!(item_id: item14._id.to_s, column_id: column2._id.to_s, value: 5.0, item_identifier: item14.identifier) }
  let(:item_value23) { report_data8.item_values.create!(item_id: item9._id.to_s, column_id: column2._id.to_s, value: 6.0, item_identifier: item9.identifier) }
  let(:item_value24) { report_data9.item_values.create!(item_id: item9._id.to_s, column_id: column2._id.to_s, value: 7.0, item_identifier: item9.identifier) }
  let(:item_value25) { report_data10.item_values.create!(item_id: item9._id.to_s, column_id: column2._id.to_s, value: 8.0, item_identifier: item9.identifier) }

  let(:revenue_report) do
    AdvancedReportFactory.create!(report_service: report_service,
                                  report_params: { template_id: 'revenue_report', name: 'revenue_report' }, current_user: user).report
  end
  let(:report_data11) { revenue_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
  let(:report_data12) { revenue_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
  let(:report_data13) { revenue_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
  let(:item11) { revenue_report.find_item_by_identifier(identifier: 'guest_begin_balance') }
  let(:item12) { revenue_report.find_item_by_identifier(identifier: 'rooms_revenue') }
  let(:item13) { revenue_report.find_item_by_identifier(identifier: 'guest_end_balance') }
  let(:column3) { revenue_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value29) { report_data11.item_values.create!(item_id: item11._id.to_s, column_id: column3._id.to_s, value: 3.0, item_identifier: item11.identifier) }
  let(:item_value30) { report_data12.item_values.create!(item_id: item11._id.to_s, column_id: column3._id.to_s, value: 4.0, item_identifier: item11.identifier) }
  let(:item_value31) { report_data13.item_values.create!(item_id: item11._id.to_s, column_id: column3._id.to_s, value: 5.0, item_identifier: item11.identifier) }
  let(:item_value32) { report_data11.item_values.create!(item_id: item12._id.to_s, column_id: column3._id.to_s, value: 6.0, item_identifier: item12.identifier) }
  let(:item_value33) { report_data12.item_values.create!(item_id: item12._id.to_s, column_id: column3._id.to_s, value: 7.0, item_identifier: item12.identifier) }
  let(:item_value34) { report_data13.item_values.create!(item_id: item12._id.to_s, column_id: column3._id.to_s, value: 8.0, item_identifier: item12.identifier) }
  let(:item_value35) { report_data11.item_values.create!(item_id: item13._id.to_s, column_id: column3._id.to_s, value: 6.0, item_identifier: item13.identifier) }
  let(:item_value36) { report_data12.item_values.create!(item_id: item13._id.to_s, column_id: column3._id.to_s, value: 7.0, item_identifier: item13.identifier) }
  let(:item_value37) { report_data13.item_values.create!(item_id: item13._id.to_s, column_id: column3._id.to_s, value: 8.0, item_identifier: item13.identifier) }

  describe '#several_months_report_datas' do
    let(:report_datas_params) do
      {
        from: '2021-03-01',
        to: '2021-04-30'
      }
    end
    let(:report_datas_params1) do
      {
        from: '2023-04-01',
        to: '2023-06-30'
      }
    end
    let(:par_column) { owners_report.columns.find_by(type: 'actual_per_metric', per_metric: 'rooms_available', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:por_column) { owners_report.columns.find_by(type: 'actual_per_metric', per_metric: 'rooms_sold', range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:budget_variance_column) { owners_report.columns.find_by(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT) }

    it 'get report datas with total values' do
      daily_item_value1
      daily_item_value2
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s).value).to eq(8.0)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s).value).to eq(8.0)
      expect(report_datas.count).to eq(3)
    end

    it 'get report datas with Total Occupancy % value' do
      rooms_available_item_value1
      rooms_sold_item_value1
      rooms_available_item_value2
      rooms_sold_item_value2
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: occupancy_percent_item._id.to_s).value).to eq(40.0)
    end

    it 'get report datas with Total ADR and Total RevPar value' do
      rooms_available_item_value1
      rooms_sold_item_value1
      rooms_revenue_item_value1
      rooms_available_item_value2
      rooms_sold_item_value2
      rooms_revenue_item_value2
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: adr_item._id.to_s).value).to eq(0.75)
      expect(report_datas[0].item_values.find_by(item_id: rev_par_item._id.to_s).value).to eq(0.3)
    end

    it 'get report datas without total values' do
      report_datas_params =
        {
          from: '2021-03-01',
          to: '2021-04-30'
        }

      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: false)
      report_datas = report_data_query.report_datas
      expect(report_datas.count).to eq(2)
    end

    it 'get report datas with total values for store_managers_report' do
      report_data_query = described_class.new(report: store_managers_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item3._id.to_s, column_id: actual_column._id.to_s).value).to eq(35.0)
      expect(report_datas[0].item_values.find_by(item_id: item3._id.to_s, column_id: gross_actual_column._id.to_s).value).to eq(0.0)
      expect(report_datas[0].item_values.find_by(item_id: item4._id.to_s, column_id: actual_column._id.to_s).value).to eq(45.0)
      expect(report_datas[0].item_values.find_by(item_id: item4._id.to_s, column_id: gross_actual_column._id.to_s).value).to eq(0.0)
    end

    it 'get report datas with total values for multi_month_calculation_type' do
      executive_item_value1
      executive_item_value2
      report_data_query = described_class.new(report: executive_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: executive_item._id.to_s).value).to eq(25.0)
      expect(report_datas.count).to eq(3)
    end

    it 'get report datas with total values for cash flow report in multi month selection with new calculation type' do
      report_data_query = described_class.new(report: cash_flow_report, report_datas_params: report_datas_params1, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item5._id.to_s).value).to eq(3.0)
      expect(report_datas[0].item_values.find_by(item_id: item6._id.to_s).value).to eq(21.0)
      expect(report_datas[0].item_values.find_by(item_id: item7._id.to_s).value).to eq(24.0)
    end

    it 'get report datas with total values for revenue accounting report in multi month selection with new calculation type' do
      report_data_query = described_class.new(report: revenue_accounting_report, report_datas_params: report_datas_params1, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item8._id.to_s).value).to eq(6.0)
      expect(report_datas[0].item_values.find_by(item_id: item9._id.to_s).value).to eq(6.0)
      expect(report_datas[0].item_values.find_by(item_id: item10._id.to_s).value).to eq(18.0)
      expect(report_datas[0].item_values.find_by(item_id: item14._id.to_s).value).to eq(12.0)
    end

    it 'get report datas with total values for revenue report in multi month selection with new calculation type' do
      report_data_query = described_class.new(report: revenue_report, report_datas_params: report_datas_params1, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item11._id.to_s).value).to eq(3.0)
      expect(report_datas[0].item_values.find_by(item_id: item12._id.to_s).value).to eq(21.0)
      expect(report_datas[0].item_values.find_by(item_id: item13._id.to_s).value).to eq(8.0)
    end

    it 'get report datas with total values for PAR or POR column' do
      rooms_available_item_value1
      rooms_available_item_value2
      rooms_sold_item_value1
      rooms_sold_item_value2
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s, column_id: par_column.id.to_s).value).to eq(0.4)
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s, column_id: por_column.id.to_s).value).to eq(1)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s, column_id: par_column.id.to_s).value).to eq(0.4)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s, column_id: por_column.id.to_s).value).to eq(1)
    end

    it 'get report datas with total values for "Budget $" and "Budget Var" column' do
      item_value_for_budget1
      item_value_for_budget2
      item_value_for_budget3
      item_value_for_budget4
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: true)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s, column_id: budget_actual_column.id.to_s).budget_values[0][:value]).to eq(60)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s, column_id: budget_variance_column.id.to_s).budget_values[0][:value]).to eq(-52)
    end
  end

  describe '#report_datas with percentage column' do
    subject(:report_datas) { described_class.new(report: schedule_6_report, report_datas_params: report_datas_params, include_total: true).report_datas }

    let(:schedule_6_report) do
      AdvancedReportFactory.create!(report_service: report_service,
                                    report_params: { template_id: 'schedule_6', name: 'schedule_6' }, current_user: user).report
    end
    let(:report_datas_params) do
      {
        from: '2021-03-01',
        to: '2021-04-30',
        aggregation_columns: [Struct.new(:type).new(Column::TYPE_ACTUAL), Struct.new(:type).new(Column::TYPE_PERCENTAGE)]
      }
    end
    let(:total_non_management_item) { schedule_6_report.find_item_by_identifier(identifier: 'total_non_management') }
    let(:schedule_report_data1) { schedule_6_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
    let(:schedule_report_data2) { schedule_6_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
    let(:schedule_column) { schedule_6_report.columns.find_by(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:schedule_percentage_column) { schedule_6_report.columns.find_by(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:iv1) do
      schedule_report_data1.item_values.create!(item_id: total_non_management_item._id.to_s, column_id: schedule_column._id.to_s,
                                                value: 1.0, item_identifier: total_non_management_item.identifier)
    end
    let(:iv2) do
      schedule_report_data2.item_values.create!(item_id: total_non_management_item._id.to_s, column_id: schedule_column._id.to_s,
                                                value: 2.0, item_identifier: total_non_management_item.identifier)
    end

    context 'when call with percentage column' do
      before do
        iv1
        iv2
      end

      it 'return report datas with percentage column' do
        expect(report_datas[0].item_values.find_by(item_id: total_non_management_item._id.to_s, column_id: schedule_percentage_column._id.to_s).value).to eq(0)
      end
    end
  end

  describe 'For daily reports' do
    let(:report_datas_params) do
      {
        current: '2021-03-05',
        is_daily: true
      }
    end

    it 'get report data' do
      item_value9
      item_value10
      report_data_query = described_class.new(report: owners_report, report_datas_params: report_datas_params, include_total: false)
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item1._id.to_s).value).to eq(3.5)
      expect(report_datas[0].item_values.find_by(item_id: item2._id.to_s).value).to eq(4.5)
      expect(report_datas.count).to eq(1)
    end
  end

  describe '#last_updated_date' do
    subject(:last_updated_date) do
      described_class.new(report: owners_report, report_datas_params: params, include_total: false).last_updated_date
    end

    context 'with monthly reports' do
      let(:report_data2) do
        owners_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01',
                                           end_date: '2021-04-30', budget_ids: [1, 2, 3], updated_at: 1.day.from_now)
      end
      let(:params) do
        {
          from: '2021-03-01',
          to: '2021-04-30'
        }
      end

      it 'get report datas with total values' do
        daily_item_value1
        daily_item_value2
        expect(last_updated_date).to eq(report_data1.updated_at.to_date)
      end
    end

    context 'with daily reports' do
      let(:params) do
        {
          current: '2021-03-05',
          is_daily: true
        }
      end

      it 'get report datas with total values' do
        item_value9
        item_value10
        expect(last_updated_date).to eq(report_data4.updated_at.to_date)
      end
    end
  end
end
