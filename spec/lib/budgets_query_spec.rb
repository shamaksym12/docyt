# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetsQuery do
  let(:report_service) { instance_double('ReportService') }
  let(:params) do
    {
      order_column: 'created_at',
      order_direction: 'desc',
      page: 1,
      per: 20
    }
  end

  describe '#all_budgets' do
    let(:query) { instance_double('Query') }
    let(:budget) { instance_double('Budget') }
    let(:user) { instance_double('User') }

    before do
      allow(report_service).to receive(:budgets).and_return(query)
      allow(query).to receive(:order_by).and_return(query)
      allow(query).to receive(:page).and_return(query)
      allow(query).to receive(:per).and_return([budget])
      allow(budget).to receive(:creator_id).and_return(1)
      allow_any_instance_of(described_class).to receive(:get_users).and_return([user]) # rubocop:disable RSpec/AnyInstance
      allow(BudgetsDecorator).to receive(:decorate_collection).and_return([budget])
    end

    it 'returns decorated budgets collection' do
      budgets_query = described_class.new(report_service: report_service, params: params)
      expect(budgets_query.all_budgets).to eq([budget])
    end
  end
end
