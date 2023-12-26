# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BudgetItem, type: :model do
  it { is_expected.to be_mongoid_document }

  describe 'Associations and Fields' do
    it { is_expected.to belong_to(:budget) }
    it { is_expected.to belong_to(:standard_metric) }
    it { is_expected.to embed_many(:budget_item_values) }

    it { is_expected.to have_field(:chart_of_account_id).of_type(Integer) }
    it { is_expected.to have_field(:accounting_class_id).of_type(Integer) }
    it { is_expected.to have_field(:position).of_type(Integer) }
    it { is_expected.to have_field(:is_blank).of_type(Mongoid::Boolean) }
    it { is_expected.to have_field(:_type).of_type(String) }
  end
end
