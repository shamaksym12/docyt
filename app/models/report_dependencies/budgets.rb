# frozen_string_literal: true

module ReportDependencies
  class Budgets < Base
    def calculate_digest
      return nil if @report_data.daily?

      Budget.where(report_service: @report_data.report.report_service, year: @report_data.start_date.year).sort_by(&:_id).map(&:updated_at).join(';')
    end
  end
end
