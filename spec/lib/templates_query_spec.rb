# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplatesQuery do
  describe '.all_template_files' do
    it 'lists all files' do
      files = described_class.all_template_files
      expect(files.length).to be > 10
      expect(files).to include(Rails.root.join('app/assets/jsons/templates/schedule_6.json').to_s)
    end
  end

  describe '#template' do
    it 'returns a template' do
      result = described_class.new.template(template_id: 'administrative_general')
      expect(result[:standard_category_ids]).to eq([9])
      expect(result[:category]).to eq(Report::DEPARTMENT_REPORT_CATEGORY)
    end
  end

  describe '#templates' do
    subject(:templates) { described_class.new(query_params).templates }

    context 'when standard_category_id is Hospitality industry' do
      let(:query_params) { { standard_category_id: 9 } }

      it 'returns templates for Hospitality' do
        expect(templates.size).to eq(24)
      end
    end

    context 'when standard_category_id is unknown industry' do
      let(:query_params) { { standard_category_id: Faker::Number.number(digits: 10) } }

      it 'returns templates with standard_category_ids of nil' do
        expect(templates.detect { |template| template[:standard_category_ids].nil? }).not_to be_nil
      end
    end

    context 'when standard_category_id is UPS Industry' do
      let(:query_params) { { standard_category_id: 8 } }

      it 'returns templates for UPS industry' do
        expect(templates.size).to eq(9)
      end
    end

    context 'when standard_category_ids is Hospitality and UPS Industry' do
      let(:query_params) { { standard_category_ids: [8, 9] } }

      it 'returns templates for Hospitality and UPS Industry' do
        expect(templates.size).to eq(26)
      end
    end

    context 'when standard_category_id is Saas' do
      let(:query_params) { { standard_category_id: 11 } }

      it 'returns templates for Saas' do
        expect(templates.size).to eq(7)
      end
    end
  end

  describe '#all_templates' do
    subject(:all_templates) { described_class.new.all_templates }

    it 'returns all templates' do
      expect(all_templates.size).to be > 10
    end

    it 'returns all templates, including templates with standard_category_ids of nil' do
      expect(all_templates.detect { |template| template[:standard_category_ids].nil? }).not_to be_nil
    end
  end
end
