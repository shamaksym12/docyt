# frozen_string_literal: true

require 'rails_helper'

module ItemValues # rubocop:disable Metrics/ModuleLength
  RSpec.describe ItemValueCreator do
    before do
      allow(ItemActualsValue::ItemActualsValueCreator).to receive(:new).and_return(item_actuals_value_creator)
      allow(ItemActualPerMetricValueCreator).to receive(:new).and_return(item_actual_per_metric_value_creator)
      allow(ItemPercentageValueCreator).to receive(:new).and_return(item_percentage_value_creator)
      allow(ItemVarianceValueCreator).to receive(:new).and_return(item_variance_value_creator)
      allow(ItemBudgetActualsValueCreator).to receive(:new).and_return(item_budget_actuals_value_creator)
      allow(ItemBudgetPercentageValueCreator).to receive(:new).and_return(item_budget_percentage_value_creator)
      allow(ItemBudgetVarianceValueCreator).to receive(:new).and_return(item_budget_variance_value_creator)
    end

    let(:item_actuals_value_creator) { instance_double(ItemActualsValue::ItemActualsValueCreator, call: true) }
    let(:item_actual_per_metric_value_creator) { instance_double(ItemActualPerMetricValueCreator, call: true) }
    let(:item_percentage_value_creator) { instance_double(ItemPercentageValueCreator, call: true) }
    let(:item_variance_value_creator) { instance_double(ItemVarianceValueCreator, call: true) }
    let(:item_budget_actuals_value_creator) { instance_double(ItemBudgetActualsValueCreator, call: true) }
    let(:item_budget_percentage_value_creator) { instance_double(ItemBudgetPercentageValueCreator, call: true) }
    let(:item_budget_variance_value_creator) { instance_double(ItemBudgetVarianceValueCreator, call: true) }

    let(:business_id) { Faker::Number.number(digits: 10) }
    let(:service_id) { Faker::Number.number(digits: 10) }
    let(:report_service) { ReportService.create!(service_id: service_id, business_id: business_id) }
    let(:report) { Report.create!(report_service: report_service, template_id: 'owners_operating_statement', slug: 'owners_operating_statement', name: 'report') }
    let(:report_data) { report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }

    let(:parent_item) { report.items.create!(name: 'parent_item', order: 2, identifier: 'parent_item', totals: true) }
    let(:child_item) do
      report.items.create!(name: 'child_item', order: 1, identifier: 'child_item', type_config: { 'name' => Item::TYPE_QUICKBOOKS_LEDGER }, parent_id: parent_item.id.to_s)
    end

    let(:current_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_actual_per_metric_column) { report.columns.create!(type: Column::TYPE_ACTUAL_PER_METRIC, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_gross_actual_column) { report.columns.create!(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_gross_percentage_column) { report.columns.create!(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_variance_column) { report.columns.create!(type: Column::TYPE_VARIANCE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_budget_actual_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_budget_percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:current_budget_variance_column) { report.columns.create!(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:ytd_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_percentage_column) { report.columns.create!(type: Column::TYPE_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_gross_actual_column) { report.columns.create!(type: Column::TYPE_GROSS_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_gross_percentage_column) { report.columns.create!(type: Column::TYPE_GROSS_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_variance_column) { report.columns.create!(type: Column::TYPE_VARIANCE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_budget_actual_column) { report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_budget_percentage_column) { report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:ytd_budget_variance_column) { report.columns.create!(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_YTD, year: Column::YEAR_CURRENT) }
    let(:current_ly_actual_column) { report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_PRIOR) }

    let(:department_report) { Report.create!(report_service: report_service, template_id: Report::DEPARTMENT_REPORT, slug: Report::DEPARTMENT_REPORT, name: 'report') }
    let(:department_actual_column) { department_report.columns.create!(type: Column::TYPE_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_budget_actual_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_ACTUAL, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_budget_percentage_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_PERCENTAGE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_budget_variance_column) { department_report.columns.create!(type: Column::TYPE_BUDGET_VARIANCE, range: Column::RANGE_CURRENT, year: Column::YEAR_CURRENT) }
    let(:department_report_data) { department_report.report_datas.create!(period_type: ReportData::PERIOD_MONTHLY, start_date: '2021-02-01', end_date: '2021-02-28') }
    let(:caching_general_ledgers_service) { Quickbooks::CachingGeneralLedgersService.new(report_service) }
    let(:caching_report_datas_service) { ItemValues::CachingReportDatasService.new(report_service) }

    describe '#call' do
      subject(:create_item_value) do
        described_class.new(
          report_data: report_data,
          standard_metrics: [],
          dependent_report_datas: [],
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call(item: child_item, column: current_column)
      end

      context 'when current_column is current actual column' do
        let(:current_column) { current_actual_column }

        it 'calls ItemActualsValueCreator once' do
          create_item_value
          expect(item_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current actual_per_metric column' do
        let(:current_column) { current_actual_per_metric_column }

        it 'calls ItemActualPerMetricValueCreator once' do
          create_item_value
          expect(item_actual_per_metric_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current gross actual column' do
        let(:current_column) { current_gross_actual_column }

        it 'calls ItemActualsValueCreator once' do
          create_item_value
          expect(item_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current percentage column' do
        let(:current_column) { current_percentage_column }

        it 'calls ItemPercentageValueCreator once' do
          create_item_value
          expect(item_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current gross percentage column' do
        let(:current_column) { current_gross_percentage_column }

        it 'calls ItemPercentageValueCreator once' do
          create_item_value
          expect(item_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current variance column' do
        let(:current_column) { current_variance_column }

        it 'calls ItemVarianceValueCreator once' do
          create_item_value
          expect(item_variance_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current budget actual column' do
        let(:current_column) { current_budget_actual_column }

        it 'calls ItemBudgetActualsValueCreator once' do
          create_item_value
          expect(item_budget_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current budget percentage column' do
        let(:current_column) { current_budget_percentage_column }

        it 'calls ItemBudgetPercentageValueCreator once' do
          create_item_value
          expect(item_budget_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is current budget variance column' do
        let(:current_column) { current_budget_variance_column }

        it 'calls ItemBudgetVarianceValueCreator once' do
          create_item_value
          expect(item_budget_variance_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd actual column' do
        let(:current_column) { ytd_actual_column }

        it 'calls ItemActualsValueCreator once' do
          create_item_value
          expect(item_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd gross actual column' do
        let(:current_column) { ytd_gross_actual_column }

        it 'calls ItemActualsValueCreator once' do
          create_item_value
          expect(item_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd percentage column' do
        let(:current_column) { ytd_percentage_column }

        it 'calls ItemPercentageValueCreator once' do
          create_item_value
          expect(item_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd gross percentage column' do
        let(:current_column) { ytd_gross_percentage_column }

        it 'calls ItemPercentageValueCreator once' do
          create_item_value
          expect(item_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd variance column' do
        let(:current_column) { ytd_variance_column }

        it 'calls ItemVarianceValueCreator once' do
          create_item_value
          expect(item_variance_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd budget actual column' do
        let(:current_column) { ytd_budget_actual_column }

        it 'calls ItemBudgetActualsValueCreator once' do
          create_item_value
          expect(item_budget_actuals_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd budget percentage column' do
        let(:current_column) { ytd_budget_percentage_column }

        it 'calls ItemBudgetPercentageValueCreator once' do
          create_item_value
          expect(item_budget_percentage_value_creator).to have_received(:call).once
        end
      end

      context 'when current_column is ytd budget variance column' do
        let(:current_column) { ytd_budget_variance_column }

        it 'calls ItemBudgetVarianceValueCreator once' do
          create_item_value
          expect(item_budget_variance_value_creator).to have_received(:call).once
        end
      end

      it 'calls ItemBudgetVarianceValueCreator' do
        described_class.new(
          report_data: department_report_data,
          standard_metrics: [],
          dependent_report_datas: [],
          all_business_chart_of_accounts: [],
          accounting_classes: [],
          caching_report_datas_service: caching_report_datas_service,
          caching_general_ledgers_service: caching_general_ledgers_service
        ).call(item: child_item, column: department_budget_variance_column)
        expect(item_budget_variance_value_creator).to have_received(:call).once
      end
    end
  end
end
