# frozen_string_literal: true

require 'csv'
namespace :report_services do # rubocop:disable Metrics/BlockLength
  desc 'Sync all report_services'
  task sync_all: :environment do |_t, _args|
    SyncReportServicesService.sync
  end

  desc 'Re-update all report datas'
  task force_update_all_report_datas: :environment do |_t, _args|
    ReportData.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
    SyncReportServicesService.sync
  end

  desc 'Exports all report types as CSV'
  task export_all_report_types_as_csv: :environment do |_t, _args|
    all_templates = TemplatesQuery.new.all_templates
    title_row = ['Business Id'] + all_templates.pluck(:name)
    CSV.open('all_report_types_per_business.csv', 'wb') do |csv|
      csv << title_row
      ReportService.each do |report_service|
        business_info = [report_service.business_id]
        all_templates.each do |template|
          business_info << if report_service.reports.pluck(:template_id).include?(template[:id])
                             'Yes'
                           else
                             'No'
                           end
        end
        csv << business_info
      end
    end
  end

  desc 'Remove deleted chart_of_account_ids from item_accounts'
  task remove_deleted_chart_of_account_ids: :environment do |_t, _args|
    ReportService.all.each do |report_service|
      business_api_instance = DocytServerClient::BusinessApi.new
      response = business_api_instance.get_all_business_chart_of_accounts(report_service.business_id)
      all_business_chart_of_accounts = response.business_chart_of_accounts
      response = business_api_instance.get_accounting_classes(report_service.business_id)
      accounting_classes = response.accounting_classes

      report_service.reports.each do |report|
        report.all_item_accounts.each do |item_account|
          next if item_account.chart_of_account_id.blank?

          business_chart_of_account = all_business_chart_of_accounts.detect { |category| category.chart_of_account_id == item_account.chart_of_account_id }
          item_account.destroy! if business_chart_of_account.nil?

          next if item_account.accounting_class_id.blank?

          accounting_class = accounting_classes.detect { |category| category.id == item_account.accounting_class_id }
          next if accounting_class.present?

          if report.departmental_report?
            item_account.item.destroy!
          else
            item_account.destroy!
          end
        end
      end
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
    end
  end
end
