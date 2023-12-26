# frozen_string_literal: true

class VendorReportFactory < ReportFactory
  def sync_report_infos(report:)
    fetch_business_information(report.report_service)
    fetch_business_vendors(business_id: report.report_service.business_id)
    super(report: report)
  end

  private

  def sync_items_with_template(report:, items:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Lint/UnusedMethodArgument, Metrics/PerceivedComplexity
    total_item_name = 'Total Expenses'
    total_item_identifier = 'vendor_total_expenses'
    total_item_order = 1_000_000
    sub_items_for_total = []
    type_config_stats = { 'name' => 'stats' }
    total_vendor_item = report.items.detect { |item| item.identifier == total_item_identifier }
    if total_vendor_item.present?
      total_vendor_item.update!(name: total_item_name, order: total_item_order, totals: false, type_config: type_config_stats)
    else
      total_vendor_item = report.items.create!(name: total_item_name, order: total_item_order, identifier: total_item_identifier, totals: false, type_config: type_config_stats)
    end
    all_item_ids = [total_vendor_item.id.to_s]
    item_order = 0
    @business_vendors.each do |business_vendor| # rubocop:disable Metrics/BlockLength
      next if business_vendor.qbo_id.nil?

      type_config_general_ledger = {
        'name' => 'quickbooks_ledger',
        'general_ledger_options' => {
          'only_vendors' => [business_vendor.qbo_id],
          'include_account_types' => [
            'Expense',
            'Cost Of Goods Sold',
            'Other Expense',
            'Income',
            'Other Income'
          ]
        }
      }
      vendor_item = report.items.detect { |item| item.identifier == business_vendor.qbo_id }
      if vendor_item.present?
        vendor_item.update!(name: business_vendor.name, order: item_order, totals: false, type_config: type_config_general_ledger)
      else
        vendor_item = report.items.create!(name: business_vendor.name,
                                           order: item_order,
                                           identifier: business_vendor.qbo_id,
                                           totals: false,
                                           type_config: type_config_general_ledger)
      end
      item_order += 1
      all_item_ids << vendor_item.id.to_s
      values_config = {
        percentage: {
          value: {
            expression: {
              operator: '%',
              arg1: {
                item_id: vendor_item.identifier
              },
              arg2: {
                item_id: total_vendor_item.identifier
              }
            }
          }
        }
      }
      sub_items_for_total << { id: vendor_item.identifier, negative: false }
      vendor_item.update(values_config: values_config)
    end

    total_values_config = {
      actual: {
        value: {
          expression: {
            operator: 'sum',
            arg: {
              sub_items: sub_items_for_total
            }
          }
        }
      },
      percentage: {
        value: {
          expression: {
            operator: '%',
            arg1: {
              item_id: total_vendor_item.identifier
            },
            arg2: {
              item_id: total_vendor_item.identifier
            }
          }
        }
      }
    }
    total_vendor_item.update(values_config: total_values_config)
    report.items.where.not(_id: { '$in': all_item_ids }).delete_all
  end
end
