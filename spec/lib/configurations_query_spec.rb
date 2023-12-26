# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConfigurationsQuery do
  describe '#configuration' do
    subject(:configuration) { described_class.new.configuration(configuration_id: configuration_id) }

    context 'with First Drill Down configurations' do
      let(:configuration_id) { ConfigurationsQuery::FIRST_DRILLDOWN_CONFIGURATION }

      it 'returns a configuration' do
        result = configuration
        expect(result[:name]).to eq('First Drill Down Columns')
        expect(result[:columns].length).to eq(32)
      end
    end

    context 'with Filter configurations' do
      let(:configuration_id) { ConfigurationsQuery::REPORT_FILTER_CONFIGURATION }

      it 'returns a configuration' do
        expect(configuration[:report_filter]).not_to be_nil
      end
    end

    context 'with Multi Range configurations' do
      let(:configuration_id) { ConfigurationsQuery::MULTI_RANGE_CONFIGURATION }

      it 'returns a configuration' do
        expect(configuration[:columns]).not_to be_nil
      end
    end
  end

  describe '#all_configurations' do
    subject(:all_configurations) { described_class.new.all_configurations }

    it 'returns all configurations' do
      expect(all_configurations.size).to be > 0
    end
  end
end
