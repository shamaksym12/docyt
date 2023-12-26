# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MultiBusinessReportDatasQuery do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
    allow(DocytServerClient::MultiBusinessReportServiceApi).to receive(:new).and_return(multi_business_service_api_instance)
    allow(DocytServerClient::BusinessApi).to receive(:new).and_return(business_api_instance)
    item_value1
    item_value2
    item_value3
    item_value4
    item_value5
    item_value6
    item_value7
    item_value8
    item_value9
    item_value10
    item_value11
    item_value12
    item_value13
    item_value14
    item_value15
    item_value16
    item_value17
    item_value18
    multi_business_report
  end

  let(:business_id1) { Faker::Number.number(digits: 10) }
  let(:business_id2) { Faker::Number.number(digits: 10) }
  let(:service_id1) { Faker::Number.number(digits: 10) }
  let(:service_id2) { Faker::Number.number(digits: 10) }
  let(:user) { Struct.new(:id).new(Faker::Number.number(digits: 10)) }
  let(:multi_business_service_id) { Faker::Number.number(digits: 10) }
  let(:multi_business_service) { Struct.new(:id, :consumer_id).new(multi_business_service_id, user.id) }
  let(:multi_business_service_api_instance) { instance_double(DocytServerClient::MultiBusinessReportServiceApi, get_by_user_id: multi_business_service) }
  let(:report_service1) { ReportService.create!(service_id: service_id1, business_id: business_id1) }
  let(:report_service2) { ReportService.create!(service_id: service_id2, business_id: business_id2) }
  let(:custom_report) { Report.create!(report_service: report_service1, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
  let(:report_data1) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-03-01', end_date: '2021-03-31') }
  let(:report_data2) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-04-01', end_date: '2021-04-30') }
  let(:report_data3) { custom_report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2021-04-21', end_date: '2021-04-21') }
  let(:item1) { custom_report.items.find_or_create_by!(name: 'name1', order: 1, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
  let(:item2) { custom_report.items.find_or_create_by!(name: 'name2', order: 2, identifier: 'parent_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
  let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value1) { report_data1.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: 'parent_item') }
  let(:item_value2) { report_data1.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: 'parent_item1') }
  let(:item_value3) { report_data2.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 3.0, item_identifier: 'parent_item') }
  let(:item_value4) { report_data2.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 4.0, item_identifier: 'parent_item1') }
  let(:item_value5) { report_data3.item_values.create!(item_id: item1._id.to_s, column_id: column._id.to_s, value: 1.0, item_identifier: 'parent_item') }
  let(:item_value6) { report_data3.item_values.create!(item_id: item2._id.to_s, column_id: column._id.to_s, value: 7.0, item_identifier: 'parent_item1') }
  let(:multi_business_report) do
    MultiBusinessReportFactory.create!(current_user: user, params: { report_service_ids: [service_id1], template_id: 'owners_operating_statement',
                                                                     name: 'name1' }).multi_business_report
  end

  let(:custom_report1) do
    Report.create!(report_service: report_service1, template_id: 'advanced_balance_sheet',
                   slug: 'advanced_balance_sheet', name: 'name2', dependent_template_ids: ['owners_operating_statement'])
  end
  let(:report_data4) { custom_report1.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
  let(:report_data5) { custom_report1.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
  let(:report_data6) { custom_report1.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
  let(:item3) do
    custom_report1.items.find_or_create_by!(name: 'Net Income', order: 1, identifier: 'net_income', type_config: { 'name' => Item::TYPE_REFERENCE,
                                                                                                                   'reference' => 'owners_operating_statement/net_income',
                                                                                                                   'src_column_range' => 'ytd' })
  end
  let(:item4) do
    custom_report1.items.find_or_create_by!(name: 'House Banks', order: 1, identifier: 'house_banks', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER,
                                                                                                                     'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE })
  end
  let(:column1) { custom_report1.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value7) { report_data4.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 3.0, item_identifier: item3.identifier) }
  let(:item_value8) { report_data5.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 4.0, item_identifier: item3.identifier) }
  let(:item_value9) { report_data6.item_values.create!(item_id: item3._id.to_s, column_id: column1._id.to_s, value: 5.0, item_identifier: item3.identifier) }
  let(:item_value10) { report_data4.item_values.create!(item_id: item4._id.to_s, column_id: column1._id.to_s, value: 6.0, item_identifier: item4.identifier) }
  let(:item_value11) { report_data5.item_values.create!(item_id: item4._id.to_s, column_id: column1._id.to_s, value: 7.0, item_identifier: item4.identifier) }
  let(:item_value12) { report_data6.item_values.create!(item_id: item4._id.to_s, column_id: column1._id.to_s, value: 8.0, item_identifier: item4.identifier) }

  let(:custom_report2) do
    Report.create!(report_service: report_service2, template_id: 'advanced_balance_sheet',
                   slug: 'advanced_balance_sheet', name: 'name3', dependent_template_ids: ['owners_operating_statement'])
  end
  let(:report_data7) { custom_report2.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-04-01', end_date: '2023-04-30') }
  let(:report_data8) { custom_report2.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-05-01', end_date: '2023-05-31') }
  let(:report_data9) { custom_report2.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2023-06-01', end_date: '2023-06-30') }
  let(:item5) do
    custom_report2.items.find_or_create_by!(name: 'Net Income', order: 1, identifier: 'net_income', type_config: { 'name' => Item::TYPE_REFERENCE,
                                                                                                                   'reference' => 'owners_operating_statement/net_income',
                                                                                                                   'src_column_range' => 'ytd' })
  end
  let(:item6) do
    custom_report2.items.find_or_create_by!(name: 'House Banks', order: 1, identifier: 'house_banks', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER,
                                                                                                                     'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE })
  end
  let(:column2) { custom_report2.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
  let(:item_value13) { report_data7.item_values.create!(item_id: item5._id.to_s, column_id: column2._id.to_s, value: 1.0, item_identifier: item5.identifier) }
  let(:item_value14) { report_data8.item_values.create!(item_id: item5._id.to_s, column_id: column2._id.to_s, value: 2.0, item_identifier: item5.identifier) }
  let(:item_value15) { report_data9.item_values.create!(item_id: item5._id.to_s, column_id: column2._id.to_s, value: 3.0, item_identifier: item5.identifier) }
  let(:item_value16) { report_data7.item_values.create!(item_id: item6._id.to_s, column_id: column2._id.to_s, value: 4.0, item_identifier: item6.identifier) }
  let(:item_value17) { report_data8.item_values.create!(item_id: item6._id.to_s, column_id: column2._id.to_s, value: 5.0, item_identifier: item6.identifier) }
  let(:item_value18) { report_data9.item_values.create!(item_id: item6._id.to_s, column_id: column2._id.to_s, value: 6.0, item_identifier: item6.identifier) }

  let(:multi_business_report1) do
    MultiBusinessReportFactory.create!(current_user: user, params: { report_service_ids: [service_id1, service_id2], template_id: 'advanced_balance_sheet',
                                                                     name: 'name2' }).multi_business_report
  end
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, report_service_admin_users: users_response) }
  let(:business_chart_of_accounts_response) { Struct.new(:business_chart_of_accounts).new([]) }
  let(:business_api_instance) { instance_double(DocytServerClient::BusinessApi, get_all_business_chart_of_accounts: business_chart_of_accounts_response) }

  describe '#several_months_report_datas' do
    it 'get aggregated monthly report datas' do
      report_data_query = described_class.new(multi_business_report: multi_business_report, report_datas_params: { from: '2021-03-01'.to_date, to: '2021-04-30'.to_date })
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values[0].value).to eq(6.0)
      expect(report_datas[0].item_values[1].value).to eq(8.0)
      expect(report_datas.count).to eq(2)
    end

    it 'get aggregated daily report datas' do
      report_data_query = described_class.new(multi_business_report: multi_business_report, report_datas_params: { current: '2021-04-21'.to_date, is_daily: true })
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values[0].value).to eq(1.0)
      expect(report_datas[0].item_values[1].value).to eq(7.0)
      expect(report_datas.count).to eq(2)
    end

    it 'get aggregated monthly report datas for advanced balance sheet in multi month selection with new calculation type' do
      report_data_query = described_class.new(multi_business_report: multi_business_report1, report_datas_params: { from: '2023-03-01'.to_date, to: '2023-06-30'.to_date })
      report_datas = report_data_query.report_datas
      expect(report_datas[0].item_values.find_by(item_id: item3._id.to_s).value).to eq(8.0)
      expect(report_datas[0].item_values.find_by(item_id: item4._id.to_s).value).to eq(14.0)
    end
  end

  describe '#report_datas for stats item' do
    subject(:report_data_query) do
      described_class.new(multi_business_report: revenue_multi_business_report,
                          report_datas_params: { from: '2023-03-01'.to_date, to: '2023-06-30'.to_date })
    end

    let(:revenue_accounting_report) do
      AdvancedReportFactory.create!(report_service: report_service1,
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
    let(:revenue_multi_business_report) do
      MultiBusinessReportFactory.create!(current_user: user, params: { report_service_ids: [service_id1], template_id: 'revenue_accounting_report',
                                                                       name: 'name2' }).multi_business_report
    end

    context 'when call with percentage column' do
      before do
        item_value20
        item_value21
        item_value22
        item_value23
        item_value24
        item_value25
      end

      it 'return report datas with percentage column' do
        report_datas = report_data_query.report_datas
        expect(report_datas[0].item_values.find_by(item_identifier: 'ending_accounts_receivables').value).to eq(12.0)
      end
    end
  end
end
