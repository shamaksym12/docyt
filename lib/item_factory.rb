# frozen_string_literal: true

class ItemFactory
  include DocytLib::Utils::DocytInteractor
  attr_accessor :items

  def report_items(report:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    reference_items = []
    metric_items = []
    qbo_general_ledger_items = []
    stats_items = []
    total_items = []
    report.items.each do |item|
      if item.type_config.present?
        case item.type_config['name']
        when Item::TYPE_METRIC
          metric_items << item
        when Item::TYPE_REFERENCE
          reference_items << item
        when Item::TYPE_QUICKBOOKS_LEDGER
          qbo_general_ledger_items << item
        when Item::TYPE_STATS
          stats_items << item
        end
      elsif item.totals
        total_items << item
      end
    end
    @items = metric_items + reference_items + qbo_general_ledger_items + total_items + stats_items
  end
end
