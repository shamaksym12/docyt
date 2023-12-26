# frozen_string_literal: true

module ReportDependencies
  class OtherReports < Base
    def calculate_digest
      other_report_datas = @report_data.dependent_report_datas.values.map { |report_data| report_data.dependency_digests.values.sort }
      DocytLib::Encryption::Digest.dataset_digest(other_report_datas)
    end
  end
end
