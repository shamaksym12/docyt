# frozen_string_literal: true

FactoryBot.define do
  factory :budget do
    report_service
    name { Faker::Lorem.characters(12) }
    year { 2022 }
  end

  factory :report do
    report_service
    template_id { 'owners_operating_statement' }
    name { Faker::Lorem.characters(12) }
  end

  factory :advanced_report do
    report_service
    template_id { 'owners_operating_statement' }
    name { Faker::Lorem.characters(12) }
  end

  factory :report_data do
    report
  end

  factory :report_service do
    business_id { Faker::Number.number(10) }
    service_id { Faker::Number.number(10) }
  end

  factory :report_service_options do
    report_service
    default_budget { create(:budget) }
  end

  factory :unincluded_line_item_detail, class: 'Quickbooks::UnincludedLineItemDetail' do
    report
  end

  factory :export_report

  factory :export_budget
end
