# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DateRangeHelper do
  let(:report_service) { ReportService.create!(service_id: 132, business_id: 111) }

  describe '#item_value_calculation_date_range with monthly report' do
    subject(:item_value_calculation_date_range) { described_class.item_value_calculation_date_range(report_data: report_data, column: column, item: item) }

    let(:custom_report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'name1') }
    let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-01'.to_date, end_date: '2021-03-31'.to_date, period_type: ReportData::PERIOD_MONTHLY) }
    let(:general_ledger_item) do
      custom_report.items.create!(
        name: 'general ledger item', order: 1,
        identifier: 'general_ledger_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER
        }
      )
    end
    let(:balance_sheet_item) do
      custom_report.items.create!(
        name: 'balance sheet item', order: 1,
        identifier: 'balance_sheet_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => 'balance_sheet',
          'balance_sheet_options' => {
            'balance_day' => 'current'
          }
        }
      )
    end
    let(:balance_sheet_prior_item) do
      custom_report.items.create!(
        name: 'balance sheet prior item', order: 2,
        identifier: 'balance_sheet_prior_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => 'balance_sheet',
          'balance_sheet_options' => {
            'balance_day' => 'prior_day'
          }
        }
      )
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { general_ledger_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_PRIOR column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
      let(:item) { general_ledger_item }

      it 'returns start_date(1 year prior) and end_date(one year prior) of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.year)
        expect(date_range.last).to eq(report_data.end_date - 1.year)
      end
    end

    context 'with RANGE_CURRENT and PREVIOUS_PERIOD column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
      let(:item) { general_ledger_item }

      it 'returns start_date(1 month prior) and end_date(one month prior) of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.month)
        expect(date_range.last).to eq(report_data.end_date - 1.month)
      end
    end

    context 'with RANGE_YTD and YEAR_CURRENT column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
      let(:item) { general_ledger_item }

      it 'returns start_date(January 1st) and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date.at_beginning_of_year)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and balance_sheet item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { balance_sheet_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and prior balance_sheet item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { balance_sheet_prior_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.month)
        expect(date_range.last).to eq(report_data.end_date - 1.month)
      end
    end
  end

  describe '#item_value_calculation_date_range with daily report' do
    subject(:item_value_calculation_date_range) { described_class.item_value_calculation_date_range(report_data: report_data, column: column, item: item) }

    let(:custom_report) { Report.create!(report_service: report_service, template_id: 'revenue_report', slug: 'revenue_report', name: 'Daily Revenue Report') }
    let(:report_data) { create(:report_data, report: custom_report, start_date: '2021-03-11'.to_date, end_date: '2021-03-11'.to_date, period_type: ReportData::PERIOD_DAILY) }
    let(:general_ledger_item) do
      custom_report.items.create!(
        name: 'general ledger item', order: 1,
        identifier: 'general_ledger_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER
        }
      )
    end
    let(:balance_sheet_item) do
      custom_report.items.create!(
        name: 'balance sheet item', order: 1,
        identifier: 'balance_sheet_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => 'balance_sheet',
          'balance_sheet_options' => {
            'balance_day' => 'current'
          }
        }
      )
    end
    let(:balance_sheet_prior_item) do
      custom_report.items.create!(
        name: 'balance sheet prior item', order: 2,
        identifier: 'balance_sheet_prior_item',
        type_config: {
          'name' => Item::TYPE_QUICKBOOKS_LEDGER,
          'calculation_type' => 'balance_sheet',
          'balance_sheet_options' => {
            'balance_day' => 'prior_day'
          }
        }
      )
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { general_ledger_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_PRIOR column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }
      let(:item) { general_ledger_item }

      it 'returns start_date(1 year prior) and end_date(one year prior) of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.year)
        expect(date_range.last).to eq(report_data.end_date - 1.year)
      end
    end

    context 'with RANGE_CURRENT and PREVIOUS_PERIOD column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::PREVIOUS_PERIOD) }
      let(:item) { general_ledger_item }

      it 'returns start_date(1 month prior) and end_date(one month prior) of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.day)
        expect(date_range.last).to eq(report_data.end_date - 1.day)
      end
    end

    context 'with RANGE_MTD and YEAR_CURRENT column and general_ledger_item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_MTD, year: Column::YEAR_CURRENT) }
      let(:item) { general_ledger_item }

      it 'returns start_date(1st day of the month) and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date.at_beginning_of_month)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and balance_sheet item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { balance_sheet_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date)
        expect(date_range.last).to eq(report_data.end_date)
      end
    end

    context 'with RANGE_CURRENT and YEAR_CURRENT column and prior balance_sheet item' do
      let(:column) { custom_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
      let(:item) { balance_sheet_prior_item }

      it 'returns start_date and end_date of ReportData' do
        date_range = item_value_calculation_date_range
        expect(date_range.first).to eq(report_data.start_date - 1.day)
        expect(date_range.last).to eq(report_data.end_date - 1.day)
      end
    end
  end
end
