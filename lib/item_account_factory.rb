# frozen_string_literal: true

class ItemAccountFactory < BaseService
  include DocytLib::Utils::DocytInteractor

  def create_batch(current_item:, maps: [])
    maps.each do |map|
      current_item.item_accounts.find_or_initialize_by(chart_of_account_id: map[:chart_of_account_id], accounting_class_id: map[:accounting_class_id])
    end
    current_item.save!
  end

  def destroy_batch(item_accounts:)
    item_accounts.map(&:destroy!)
  end

  def copy_mapping(src_report:, target_report:)
    fetch_chart_of_accounts_info(src_report: src_report, target_report: target_report)
    src_report.items.each do |item|
      copy_item_accounts(item: item, target_report: target_report)
    end
  end

  def load_default_mapping(report:)
    fetch_all_business_chart_of_accounts(business_id: report.report_service.business_id)
    @default_chart_of_account_ids = []
    report.items.each do |item|
      load_default_accounts(item: item)
    end
    report.update!(accepted_chart_of_account_ids: @default_chart_of_account_ids)
  end

  private

  def fetch_chart_of_accounts_info(src_report:, target_report:)
    fetch_business_information(src_report.report_service)
    @src_business_chart_of_accounts = @all_business_chart_of_accounts
    @src_business_accounting_classes = @accounting_classes

    fetch_business_information(target_report.report_service)
    @target_business_chart_of_accounts = @all_business_chart_of_accounts
    @target_business_accounting_classes = @accounting_classes
  end

  def copy_item_accounts(item:, target_report:)
    target_item = target_report.find_item_by_identifier(identifier: item.identifier)
    target_item.item_accounts.destroy_all
    item.item_accounts.each do |item_account|
      create_item_account(item: target_item, src_chart_of_account_id: item_account.chart_of_account_id, src_accounting_class_id: item_account.accounting_class_id)
    end
    target_item.save!
  end

  def create_item_account(item:, src_chart_of_account_id:, src_accounting_class_id:) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    src_business_chart_of_account = @src_business_chart_of_accounts.select { |category| category.chart_of_account_id == src_chart_of_account_id }.first
    return if src_business_chart_of_account.nil?

    target_business_chart_of_account = @target_business_chart_of_accounts.select { |category| category.display_name == src_business_chart_of_account.display_name }.first
    return if target_business_chart_of_account.nil?

    if src_accounting_class_id.blank?
      item.item_accounts.find_or_initialize_by(
        chart_of_account_id: target_business_chart_of_account.chart_of_account_id,
        accounting_class_id: nil
      )
      return
    end

    src_accounting_class = @src_business_accounting_classes.select { |business_accounting_class| business_accounting_class.id == src_accounting_class_id }.first
    return if src_accounting_class.nil?

    target_accounting_class = @target_business_accounting_classes.select { |business_accounting_class| business_accounting_class.name == src_accounting_class.name }.first
    return if target_accounting_class.nil? || target_business_chart_of_account.mapped_class_ids.exclude?(target_accounting_class&.id)

    item.item_accounts.find_or_initialize_by(
      chart_of_account_id: target_business_chart_of_account.chart_of_account_id,
      accounting_class_id: target_accounting_class.id
    )
  end

  def load_default_accounts(item:)
    item.item_accounts.destroy_all
    if item.type_config.present? && item.type_config['default_accounts'].present?
      item.type_config['default_accounts'].each do |item_account|
        @default_chart_of_account_ids += default_accepted_accounts(item_default_account_config: item_account).map(&:chart_of_account_id)

        create_default_item_account(item: item, default_account: item_account)
      end
    end
    item.save!
  end

  def default_accepted_accounts(item_default_account_config:)
    @all_business_chart_of_accounts.select do |chart_of_account|
      chart_of_account.acc_type_name == item_default_account_config['account_type'] && chart_of_account.sub_type == item_default_account_config['account_detail_type']
    end
  end

  def create_default_item_account(item:, default_account:)
    business_chart_of_accounts = @all_business_chart_of_accounts.select do |category|
      default_account['account_type'].casecmp?(category.acc_type_name) && default_account['account_detail_type'].casecmp?(category.sub_type)
    end
    return if business_chart_of_accounts.blank?

    business_chart_of_accounts.each do |business_chart_of_account|
      item.item_accounts.new(
        chart_of_account_id: business_chart_of_account.chart_of_account_id,
        accounting_class_id: nil
      )
    end
  end
end
