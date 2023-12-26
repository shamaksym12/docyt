# frozen_string_literal: true

#
# == Mongoid Information
#
# Document name: standard_metric
#
#  id                   :string
#  name                 :string
#

require 'rails_helper'

RSpec.describe StandardMetricSerializer do
  let(:standard_metric) { StandardMetric.create!(name: 'Rooms Available to sell', type: 'Availabel Rooms', code: 'rooms_available') }

  it 'contains standard_metric information in json' do
    json_string = described_class.new(standard_metric).to_json
    result_hash = JSON.parse(json_string)
    expect(result_hash['standard_metric']['id']).not_to be_nil
    expect(result_hash['standard_metric']['name']).to eq('Rooms Available to sell')
  end
end
