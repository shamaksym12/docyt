# frozen_string_literal: true

module ReportDependencies
  class Quickbooks < Base
    def calculate_digest
      common_general_ledgers = ::Quickbooks::CommonGeneralLedger.where(report_service: @report_data.report.report_service)
      common_general_ledgers = common_general_ledgers.where(
        start_date: { '$gte' => earliest_calculation_date },
        end_date: { '$lte' => latest_calculation_date }
      ).order_by(start_date: :asc)
      DocytLib::Encryption::Digest.dataset_digest(common_general_ledgers.map(&:digest))
    end

    private

    def earliest_calculation_date
      @report_data.start_date.at_beginning_of_month - 1.year
    end

    def latest_calculation_date
      @report_data.end_date.at_end_of_month
    end
  end
end
