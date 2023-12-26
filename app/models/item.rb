# frozen_string_literal: true

class Item
  include Mongoid::Document
  TYPE_METRIC = 'metric'
  TYPE_QUICKBOOKS_LEDGER = 'quickbooks_ledger'
  TYPE_STATS = 'stats'
  TYPE_REFERENCE = 'reference'

  COMMON_ITEM_ROOMS_AVAILABLE = 'rooms_available'
  COMMON_ITEM_ROOMS_SOLD = 'rooms_sold'

  CALCULATION_TYPE_CONFIG = 'calculation_type'
  GENERAL_LEDGER_CALCULATION_TYPE = 'general_ledger'
  BALANCE_SHEET_CALCULATION_TYPE = 'balance_sheet'

  BALANCE_SHEET_OPTIONS = 'balance_sheet_options'
  BALANCE_DAY_OPTIONS = 'balance_day'
  PRIOR_BALANCE_DAY = 'prior_day'

  EXCLUDE_LEDGERS_CONFIG = 'exclude_ledgers'
  EXCLUDE_LEDGERS_BANK = 'bank'
  EXCLUDE_LEDGERS_BANK_AND_AP = 'bank_and_accounts_payable'

  GENERAL_LEDGER_OPTIONS_CONFIG = 'general_ledger_options'
  OPTIONS_ONLY_VENDORS = 'only_vendors'
  OPTIONS_ONLY_CLASSES = 'only_classes'
  OPTIONS_INCLUDE_ACCOUNT_TYPES = 'include_account_types'
  OPTIONS_INCLUDE_SUBLEDGER_ACCOUNT_TYPES = 'include_subledger_account_types'
  OPTIONS_EXCLUDE_SUBLEDGER_ACCOUNT_TYPES = 'exclude_subledger_account_types'

  AMOUNT_TYPE = 'amount_type'
  AMOUNT_TYPE_DEBIT = 'debit'
  AMOUNT_TYPE_CREDIT = 'credit'

  SUMMARY_ITEM_ID = 'summary'

  PL_ACC_TYPES = ['Expense', 'Other Expense', 'Cost of Goods Sold', 'Income', 'Other Income'].freeze
  BS_ACC_TYPES = [
    'Fixed Asset', 'Equity', 'Accounts Payable', 'Accounts Receivable',
    'Long Term Liability', 'Other Current Liability', 'Credit Card',
    'Other Current Asset', 'Other Asset', 'Bank'
  ].freeze

  MULTI_MONTH_CALCULATION_AVERAGE_TYPE = 'Average'

  METRIC_CURRENCY_DATA_TYPE = 'currency'
  METRIC_INTEGER_DATA_TYPE = 'integer'

  field :name, type: String
  field :order, type: Integer
  field :identifier, type: String
  field :totals, type: Boolean, default: false
  field :show, type: Boolean, default: true
  field :type_config, type: Object
  field :values_config, type: Object
  field :negative, type: Boolean, default: false
  field :negative_for_total, type: Boolean, default: false
  field :depth_diff, type: Integer, default: 0
  field :account_type, type: String
  field :metric_data_type, type: String
  field :per_metric_calculation_enabled, type: Boolean, default: false
  field :parent_id, type: String

  validates :name, presence: true
  validates :order, presence: true
  validates :identifier, presence: true

  embedded_in :report, class_name: 'Report'
  embeds_many :item_accounts, class_name: 'ItemAccount'
  embedded_in :parent_item, class_name: 'Item', inverse_of: :child_items      # deprecated. It will be removed in ENG-19337
  embeds_many :child_items, class_name: 'Item', inverse_of: :parent_item      # deprecated. It will be removed in ENG-19337

  def item_account_count
    if totals && find_parent_item.present?
      find_parent_item.all_item_accounts.count
    else
      item_accounts.count
    end
  end

  def find_parent_item
    report.items.detect { |item| item.id.to_s == parent_id }
  end

  def all_child_items
    report.items.select { |item| item.parent_id == id.to_s }
  end

  def all_item_accounts
    item_accounts.sort_by { |item| [item[:chart_of_account_id], item[:accounting_class_id]].join(';') } + all_child_items.sort_by(&:order).map(&:all_item_accounts).flatten
  end

  def releated_to_metric?
    if all_child_items.present?
      all_child_items.any?(&:releated_to_metric?)
    else
      type_config.present? && type_config['name'] == TYPE_METRIC
    end
  end

  def use_derived_mapping?
    type_config.present? &&
      type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG].present? &&
      (type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_ONLY_VENDORS].present? ||
        type_config[Item::GENERAL_LEDGER_OPTIONS_CONFIG][Item::OPTIONS_ONLY_CLASSES].present?)
  end

  def mapped_item_accounts
    if type_config.present? && type_config['use_mapping'].present?
      item = report.find_item_by_identifier(identifier: type_config['use_mapping']['item_id'])
      return item.item_accounts if item.present?

      return []
    end
    item_accounts
  end

  def total_item
    all_child_items.detect(&:totals)
  end

  def prior_balance_day_option?
    type_config.present? && type_config[BALANCE_SHEET_OPTIONS].present? && type_config[BALANCE_SHEET_OPTIONS][BALANCE_DAY_OPTIONS] == PRIOR_BALANCE_DAY
  end
end
