# frozen_string_literal: true

namespace :custom_reports do # rubocop:disable Metrics/BlockLength
  desc 'Re-update the waiting reports'
  task re_update_waiting_report: :environment do |_t, _args|
    Report.all.each do |report|
      if Report::UPDATE_STATES_QUEUED.include?(report.update_state) || report.update_state == Report::UPDATE_STATE_STARTED
        ReportFactory.force_update_without_condition(report: report)
      end
    end
  end

  desc 'Update report infos'
  task update_report_infos: :environment do |_t, _args|
    Report.all.no_timeout.each do |report|
      next if report.report_service.blank?

      report.factory_class.sync_report_infos(report: report)
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
    end
  end

  desc 'Update report infos for special template'
  task :update_report_infos_for_template, [:template_id] => :environment do |_t, args|
    Report.where(template_id: args[:template_id]).all.no_timeout.each do |report|
      next if report.report_service.blank?

      report.factory_class.sync_report_infos(report: report)
    rescue DocytServerClient::ApiError => e
      DocytLib.logger.debug(e.message)
    end
  end

  desc 'Force refactor all Reports for special template'
  task :force_refactor_all_reports_for_template, [:template_id] => :environment do |_t, args|
    Report.where(template_id: args[:template_id]).all.no_timeout.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
      report.refresh_all_monthly_report_datas
    end
  end

  desc 'Reset dependency digests for special template reports'
  task :reset_dependency_digests_for_reports, [:template_id] => :environment do |_t, args|
    Report.where(template_id: args[:template_id]).all.each do |report|
      report.report_datas.update_all(dependency_digests: {}) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  desc 'Update slug field value with template_id'
  task update_slug_field_value_with_template_id: :environment do |_t|
    Report.each do |report|
      next if report.report_service.blank?

      report.update!(slug: report.template_id)
      puts "Updated in #{report.template_id}"
    end
  end

  desc 'Migrate from AcceptedAccountTypes to AcceptedChartOfAccountIds'
  task migrate_to_accepted_chart_of_account_ids: :environment do |_t, _args|
    Report.all.each do |report|
      next if report.accepted_account_types.count.zero?

      MigrateToAcceptedChartOfAccountsService.migrate(report: report)
    end
  end

  desc 'Update invalid report'
  task update_invalid_report: :environment do |_t|
    Report.each do |report|
      next if report.valid?

      mapped_item_accounts = []
      if report.is_a?(AdvancedReport)
        report.report_items.each do |item|
          item.item_accounts.each do |item_account|
            mapped_item_accounts << { item_identifier: item.identifier,
                                      chart_of_account_id: item_account.chart_of_account_id, accounting_class_id: item_account.accounting_class_id }
          end
        end
      end

      report.columns.delete_all

      report.items.map(&:destroy!)
      report.items.delete_all
      report.items = []
      report.save!

      report.factory_class.sync_report_infos(report: report)
      mapped_item_accounts.each do |item_account|
        item = report.find_item_by_identifier(identifier: item_account[:item_identifier])
        item.item_accounts.create!(accounting_class_id: item_account[:accounting_class_id], chart_of_account_id: item_account[:chart_of_account_id])
      end
      report.refresh_all_monthly_report_datas(priority: ReportFactory::MANUAL_UPDATE_PRIORITY)
    end
  end
end
