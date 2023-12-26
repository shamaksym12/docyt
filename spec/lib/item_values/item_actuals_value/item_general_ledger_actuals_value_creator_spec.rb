# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  module ItemActualsValue # rubocop:disable Metrics/ModuleLength
    RSpec.describe ItemGeneralLedgerActualsValueCreator do
      before do
        child_item1
        child_item2
        common_general_ledger.update!(line_item_details: line_item_details)
        prior_year_common_general_ledger.update!(line_item_details: prior_year_line_item_details)
      end

      let(:line_item_details_body) { file_fixture('qbo_general_ledger_line_item_details.json').read }
      let(:business_id) { Faker::Number.number(digits: 10) }
      let(:service_id) { Faker::Number.number(digits: 10) }
      let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
      let(:report) { Report.create!(report_service: report_service, template_id: 'operators_operating_statement', slug: 'operators_operating_statement', name: 'report') }
      let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }) }
      let(:child_item1) do
        item = report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item.item_accounts.create!(chart_of_account_id: 1004)
        item
      end
      let(:child_item2) do
        item = report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                    negative: true, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item.item_accounts.create!(chart_of_account_id: 1003)
        item
      end
      let(:child_item3) do
        item = report.items.create!(
          name: 'child_item3',
          order: 1,
          identifier: 'child_item3',
          type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
          negative_for_total: true,
          parent_id: parent_item.id.to_s
        )
        item.item_accounts.create!(chart_of_account_id: 1001)
        item
      end
      let(:vendor_item) do
        report.items.create!(name: 'parent_item', order: 1, identifier: '60', type_config: {
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
      end
      let(:general_ledger_child_item) do
        item = report.items.create!(name: 'general_ledger_child_item', order: 1, identifier: 'general_ledger_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:balance_sheet_child_item) do
        item = report.items.create!(name: 'balance_sheet_child_item', order: 1, identifier: 'balance_sheet_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:priod_day_balance_child_item) do
        item = report.items.create!(name: 'priod_day_balance_child_item', order: 1, identifier: 'priod_day_balance_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::BALANCE_SHEET_CALCULATION_TYPE,
                                                   Item::BALANCE_SHEET_OPTIONS => {
                                                     Item::BALANCE_DAY_OPTIONS => Item::PRIOR_BALANCE_DAY
                                                   } },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:associated_ledgers_child_item) do
        item = report.items.create!(name: 'associated_ledgers_child_item', order: 1, identifier: 'associated_ledgers_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:debit_child_item) do
        item = report.items.create!(name: 'debit_child_item',
                                    order: 1,
                                    identifier: 'debit_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER,
                                                   'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
                                                   'general_ledger_options' => {
                                                     'amount_type' => Item::AMOUNT_TYPE_DEBIT
                                                   } },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end
      let(:credit_child_item) do
        item = report.items.create!(name: 'credit_child_item',
                                    order: 1,
                                    identifier: 'credit_child_item',
                                    type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER,
                                                   'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
                                                   'general_ledger_options' => {
                                                     'amount_type' => Item::AMOUNT_TYPE_CREDIT
                                                   } },
                                    values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
        item.item_accounts.create!(chart_of_account_id: 1001)
        item.item_accounts.create!(chart_of_account_id: 1002)
        item
      end

      let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:previous_mtd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
      let(:mtd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT) }
      let(:item_values) do
        [
          {
            item_id: child_item1.id.to_s,
            column_id: current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            value: 20.0
          }
        ]
      end
      let(:dependent_report_item_values) do
        [
          {
            item_id: dependent_report_child_item1.id.to_s,
            column_id: dependent_report_current_actual_column.id.to_s,
            item_identifier: 'child_item1',
            value: 60.0
          }
        ]
      end
      let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2020-03-01', end_date: '2020-03-31') }
      let(:daily_report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_DAILY, start_date: '2020-05-01', end_date: '2020-05-01') }

      let(:dependent_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
      let(:dependent_report_current_actual_column) { dependent_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:dependent_report_parent_item) do
        dependent_report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER })
      end
      let(:dependent_report_child_item1) do
        item = dependent_report.items.create!(name: 'child_item1', order: 1, identifier: 'child_item1', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER },
                                              values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')),
                                              parent_id: dependent_report_parent_item.id.to_s)
        item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1001)
        item.item_accounts.create!(accounting_class_id: 1, chart_of_account_id: 1002)
        item
      end
      let(:dependent_report_child_item2) do
        item = dependent_report.items.create!(name: 'child_item2', order: 1, identifier: 'child_item2',
                                              type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, negative: true, parent_id: dependent_report_parent_item.id.to_s)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1001)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1002)
        item.item_accounts.create!(accounting_class_id: 2, chart_of_account_id: 1003)
        item
      end
      let(:dependent_report_metric_item1) do
        dependent_report.items.create!(name: 'Rooms Available to sell', order: 3, identifier: 'rooms_available',
                                       type_config: { 'name' => Item::TYPE_METRIC, 'metric' => { 'name' => 'Available Rooms' } })
      end
      let(:dependent_report_data) do
        dependent_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28', item_values: dependent_report_item_values)
      end
      let(:dependent_report_datas) { { 'owners_operating_statement' => dependent_report_data } }

      let(:common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date)
      end
      let(:prior_year_common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date - 1.year, end_date: report_data.end_date - 1.year)
      end
      let(:previous_common_general_ledger) do
        ::Quickbooks::CommonGeneralLedger.create!(report_service: report_service,
                                                  start_date: report_data.start_date - 1.month,
                                                  end_date: (report_data.start_date - 1.month).end_of_month)
      end
      let(:december_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2019-12-01', end_date: '2019-12-31')
      end
      let(:prior_december_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: '2018-12-01', end_date: '2018-12-31')
      end
      let(:current_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: report_data.start_date, end_date: report_data.end_date,
                                                        line_item_details: line_item_details)
      end
      let(:previous_month_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service,
                                                        start_date: report_data.start_date - 1.month, end_date: (report_data.start_date - 1.month).end_of_month,
                                                        line_item_details: line_item_details)
      end
      let(:current_daily_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service, start_date: daily_report_data.start_date, end_date: daily_report_data.start_date,
                                                        line_item_details: line_item_details)
      end
      let(:previous_daily_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service,
                                                        start_date: daily_report_data.start_date - 1.day, end_date: daily_report_data.start_date - 1.day,
                                                        line_item_details: line_item_details)
      end
      let(:current_mtd_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service,
                                                        start_date: daily_report_data.start_date.at_beginning_of_month, end_date: daily_report_data.start_date,
                                                        line_item_details: line_item_details)
      end
      let(:previous_mtd_bs_general_ledger) do
        ::Quickbooks::BalanceSheetGeneralLedger.create!(report_service: report_service,
                                                        start_date: daily_report_data.start_date - 1.month, end_date: daily_report_data.start_date - 1.day,
                                                        line_item_details: line_item_details)
      end

      let(:business_chart_of_account1) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 1, business_id: business_id, chart_of_account_id: 1001, qbo_id: '101', display_name: 'name1', acc_type: 'Expense')
      end
      let(:business_chart_of_account2) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 2, business_id: business_id, chart_of_account_id: 1002, qbo_id: '204', display_name: 'name2', acc_type: 'Bank')
      end
      let(:business_chart_of_account3) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 3, business_id: business_id, chart_of_account_id: 1003, qbo_id: '60', display_name: 'name3', acc_type: 'Expense')
      end
      let(:business_chart_of_account4) do
        instance_double(DocytServerClient::BusinessChartOfAccount,
                        id: 4, business_id: business_id, chart_of_account_id: 1004, qbo_id: '148', display_name: '570 Food Supplies', acc_type: 'Expense')
      end
      let(:business_chart_of_accounts) { [business_chart_of_account1, business_chart_of_account2, business_chart_of_account3, business_chart_of_account4] }
      let(:accounting_class1) { instance_double(DocytServerClient::AccountingClass, id: 1, business_id: business_id, external_id: '4', name: 'Account1') }
      let(:accounting_class2) { instance_double(DocytServerClient::AccountingClass, id: 2, business_id: business_id, external_id: '1', name: 'Account2') }
      let(:accounting_classes) { [accounting_class1, accounting_class2] }
      let(:line_item_details) do
        ::Quickbooks::GeneralLedgerAnalyzer.analyze(line_item_details_raw_data: line_item_details_body)
      end
      let(:prior_year_line_item_details) do
        prior_year_line_item_details_body = file_fixture('profit_and_loss_general_ledger_line_item_details.json').read
        ::Quickbooks::GeneralLedgerAnalyzer.analyze(line_item_details_raw_data: prior_year_line_item_details_body)
      end
      let(:bs_general_ledgers) do
        [current_bs_general_ledger, previous_month_bs_general_ledger,
         current_daily_bs_general_ledger, previous_daily_bs_general_ledger,
         current_mtd_bs_general_ledger, previous_mtd_bs_general_ledger]
      end
      let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
      let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

      # This specs has no subject and we will slowly move the business logic into `#call with subject`
      describe '#call' do
        def create_item_value # rubocop:disable Metrics/MethodLength
          described_class.new(
            report_data: report_data,
            item: child_item,
            column: current_actual_column,
            standard_metrics: [],
            dependent_report_datas: dependent_report_datas,
            all_business_chart_of_accounts: business_chart_of_accounts,
            accounting_classes: accounting_classes,
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
        end

        def create_previous_mtd_item_value # rubocop:disable Metrics/MethodLength
          described_class.new(
            report_data: report_data,
            item: child_item,
            column: previous_mtd_actual_column,
            standard_metrics: [],
            dependent_report_datas: [],
            all_business_chart_of_accounts: business_chart_of_accounts,
            accounting_classes: accounting_classes,
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
        end

        context 'when qbo_ledger is CommonGeneralLedger' do
          let(:child_item) { child_item1 }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER item and RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            item_account_value = report_data.item_account_values.first
            expect(item_value.value).to eq(-3793.12)
            expect(item_value.column_type).to eq(Column::TYPE_ACTUAL)
            expect(item_account_value.name).to eq('name1')
            expect(item_account_value.value).to eq(-3782.12)
          end
        end

        context 'when qbo_ledger is CommonGeneralLedger and item`s mapped accounting class is nil' do
          let(:child_item) { child_item3 }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER item' do
            common_general_ledger.line_item_details.first.update(accounting_class_qbo_id: 1)
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3882.12)
          end
        end

        context 'when qbo_ledger is CommonGeneralLedger in a report which accounting_class_check_disabled value is true' do
          let(:child_item) { child_item3 }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER item' do
            report.update!(accounting_class_check_disabled: true)
            common_general_ledger.line_item_details.first.update!(accounting_class_qbo_id: 1)
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3782.12)
          end
        end

        context 'when item`s calculation_type is GENERAL_LEDGER_CALCULATION_TYPE' do
          let(:child_item) { general_ledger_child_item }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER(GENERAL_LEDGER_CALCULATION_TYPE) and RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3793.12)
          end

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER(GENERAL_LEDGER_CALCULATION_TYPE) and RANGE_YTD column for last month' do
            previous_common_general_ledger.update(line_item_details: line_item_details)
            create_previous_mtd_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: previous_mtd_actual_column.id.to_s)
            expect(item_value.value).to eq(-3793.12)
          end
        end

        context 'when amount_type is debit' do
          let(:child_item) { debit_child_item }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER and RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(101)
          end
        end

        context 'when item`s calculation_type is Credits only' do
          let(:child_item) { credit_child_item }

          it 'creates item_value for TYPE_QUICKBOOKS_LEDGER and RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3894.12)
          end
        end

        context 'when item`s type name is balance_sheet' do
          let(:child_item) { balance_sheet_child_item }

          it 'creates item_value for TYPE_BALANCE_SHEET and RANGE_CURRENT column' do
            bs_general_ledgers
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3793.12)
          end
        end

        context 'when item`s type name is balance_sheet and date is START_DATE_MINUS_ONE' do
          let(:child_item) { priod_day_balance_child_item }

          it 'creates item_value for TYPE_BALANCE_SHEET(START_DATE_MINUS_ONE) and RANGE_CURRENT column' do
            bs_general_ledgers
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3793.12)
          end
        end

        context 'when item`s general ledger option is including with [Bank, Accounts Payable]' do
          let(:child_item) do
            item = report.items.create!(name: 'general_ledger_child_item', order: 1, identifier: 'include_general_ledger_child_item',
                                        type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
                                                       'general_ledger_options' => { 'include_subledger_account_types' => ['Bank', 'Accounts Payable'] } },
                                        values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
            item.item_accounts.create!(chart_of_account_id: 1001)
            item.item_accounts.create!(chart_of_account_id: 1002)
            item
          end

          it 'creates item_value for RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-11.0)
          end
        end

        context 'when item`s general ledger option is excluding with [Bank, Accounts Payable]' do
          let(:child_item) do
            item = report.items.create!(name: 'general_ledger_child_item', order: 1, identifier: 'exclude_general_ledger_child_item',
                                        type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER, 'calculation_type' => Item::GENERAL_LEDGER_CALCULATION_TYPE,
                                                       'general_ledger_options' => { 'exclude_subledger_account_types' => ['Bank', 'Accounts Payable'] } },
                                        values_config: JSON.parse(File.read('./spec/data/values_config/percentage_item.json')), parent_id: parent_item.id.to_s)
            item.item_accounts.create!(chart_of_account_id: 1001)
            item.item_accounts.create!(chart_of_account_id: 1002)
            item
          end

          it 'creates item_value for RANGE_CURRENT column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: child_item.id.to_s, column_id: current_actual_column.id.to_s)
            expect(item_value.value).to eq(-3782.12)
          end
        end
      end

      describe '#call with subject' do
        subject(:create_item_value) do
          described_class.new(
            report_data: actual_report_data,
            item: actual_item,
            column: actual_column,
            standard_metrics: [],
            dependent_report_datas: dependent_report_datas,
            all_business_chart_of_accounts: business_chart_of_accounts,
            accounting_classes: accounting_classes,
            caching_report_datas_service: caching_report_datas_service,
            caching_general_ledgers_service: caching_general_ledgers_service
          ).call
        end

        let(:dependent_report_datas) { [] }
        let(:actual_report_data) { report_data }

        context 'when column year is prior' do
          let(:actual_item) { child_item1 }
          let(:actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }

          it 'creates item_value for prior year column' do
            create_item_value
            item_value = report_data.item_values.find_by(item_id: actual_item.id.to_s, column_id: actual_column.id.to_s)
            expect(item_value.value).to eq(24.00)
          end
        end
      end
    end
  end
end
