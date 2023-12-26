# frozen_string_literal: true

module ReportDependencies
  class Mapping < Base
    def calculate_digest
      DocytLib::Encryption::Digest.dataset_digest(@report_data.report.all_item_accounts, %i[chart_of_account_id accounting_class_id])
    end
  end
end
