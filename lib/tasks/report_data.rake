# frozen_string_literal: true

namespace :report_data do # rubocop:disable Metrics/BlockLength
  desc 'Remove duplicate report_data with same report_id, start_date and end_date'
  task remove_duplicate_report_data: :environment do |_t, _args|
    ReportData.all.each do |report_data|
      next if report_data.reload.blank?

      ReportData.where(report_id: report_data.report_id, start_date: report_data.start_date, end_date: report_data.end_date).where.not(id: report_data.id).delete_all
    end
  end

  desc 'Force clear QUEUED states to FINISHED'
  task force_clear_queued_states: :environment do |_t, _args|
    Report
      .where(update_state: { '$in': [Report::UPDATE_STATE_QUEUED, Report::UPDATE_STATE_STARTED] })
      .update_all(update_state: Report::UPDATE_STATE_FINISHED) # rubocop:disable Rails/SkipsModelValidations
    ReportData
      .where(update_state: Report::UPDATE_STATE_QUEUED)
      .update_all(update_state: Report::UPDATE_STATE_FINISHED) # rubocop:disable Rails/SkipsModelValidations
  end

  desc 'Remove incorrect report_datas'
  task remove_incorrect_datas: :environment do |_t, _args|
    ReportData.all.each do |report_data|
      if report_data.period_type == ReportData::PERIOD_DAILY
        report_data.destroy! if report_data.start_date != report_data.end_date
      elsif (report_data.start_date != report_data.start_date.at_beginning_of_month) || (report_data.end_date != report_data.start_date.end_of_month)
        report_data.destroy!
      end
    end
  end

  desc 'Recalc report_data digests until 2022'
  task recalc_digests_for_old_report_datas: :environment do |_t, _args|
    ReportService.all.no_timeout.each do |report_service|
      next unless report_service.has_active_subscription?

      report_service.reports.all.no_timeout.each do |report|
        report.report_datas.where(start_date: { '$lte' => '2022-12-31' }).all.no_timeout.each(&:recalc_digest!)
      end
    end
  end
end
