# frozen_string_literal: true

require 'rails_helper'

module ItemValues
  RSpec.describe BaseItemValueCreator do
    subject(:item_value_creator) do
      described_class.new(
        report_data: report_data,
        item: nil,
        column: current_column,
        standard_metrics: [],
        dependent_report_datas: [],
        all_business_chart_of_accounts: [],
        accounting_classes: [],
        caching_report_datas_service: caching_report_datas_service,
        caching_general_ledgers_service: caching_general_ledgers_service
      )
    end

    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-07-01', end_date: '2021-07-31') }
    let(:current_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

    describe '#budgets_by_column' do
      before do
        budgets
      end

      let(:budget1) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
      let(:budget2) { Budget.create!(report_service: report_service, name: 'name', year: 2021) }
      let(:budget3) { Budget.create!(report_service: report_service, name: 'name', year: 2020) }
      let(:budgets) { [budget1, budget2, budget3] }

      it 'returns budgets for YEAR_PRIOR column' do
        current_column.update(year: Column::YEAR_PRIOR)
        budgets = item_value_creator.send(:budgets_by_column)
        expect(budgets.length).to eq(1)
      end

      it 'returns budgets for YEAR_CURRENT column' do
        budgets = item_value_creator.send(:budgets_by_column)
        expect(budgets.length).to eq(2)
      end
    end

    describe '#start_date_by_column' do
      it 'returns start_date for YEAR_PRIOR column' do
        current_column.update(year: Column::YEAR_PRIOR)
        start_date = item_value_creator.send(:start_date_by_column, report_data)
        expect(start_date).to eq(report_data.start_date - 1.year)
      end

      it 'returns start_date for PREVIOUS_PERIOD column' do
        current_column.update(year: Column::PREVIOUS_PERIOD)
        start_date = item_value_creator.send(:start_date_by_column, report_data)
        expect(start_date).to eq(report_data.start_date - 1.month)
      end

      it 'returns start_date for RANGE_MTD column' do
        report_data.update(period_type: ReportData::PERIOD_DAILY, start_date: report_data.end_date)
        current_column.update(range: Column::RANGE_MTD)
        start_date = item_value_creator.send(:start_date_by_column, report_data)
        expect(start_date).to eq(report_data.start_date.at_beginning_of_month)
      end

      it 'returns start_date for normal column' do
        start_date = item_value_creator.send(:start_date_by_column, report_data)
        expect(start_date).to eq(report_data.start_date)
      end
    end

    describe '#end_date_by_column' do
      it 'returns end_date for YEAR_PRIOR column' do
        current_column.update(year: Column::YEAR_PRIOR)
        end_date = item_value_creator.send(:end_date_by_column, report_data)
        expect(end_date).to eq((report_data.start_date - 1.year).end_of_month)
      end

      it 'returns end_date for PREVIOUS_PERIOD column' do
        current_column.update(year: Column::PREVIOUS_PERIOD)
        end_date = item_value_creator.send(:end_date_by_column, report_data)
        expect(end_date).to eq((report_data.start_date - 1.month).end_of_month)
      end

      it 'returns end_date for normal column' do
        end_date = item_value_creator.send(:end_date_by_column, report_data)
        expect(end_date).to eq(report_data.end_date)
      end
    end
  end
end
