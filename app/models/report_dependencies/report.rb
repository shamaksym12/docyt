# frozen_string_literal: true

module ReportDependencies
  class Report < Base
    def calculate_digest
      report_digests = [@report_data.report.accepted_accounting_class_ids.join(';'), @report_data.report.accepted_chart_of_account_ids.join(';')]
      DocytLib::Encryption::Digest.dataset_digest(report_digests)
    end
  end
end
