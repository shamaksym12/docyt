# frozen_string_literal: true

module ReportDependencies
  class Base
    def initialize(report_data)
      @report_data = report_data
    end

    def has_changed? # rubocop:disable Naming/PredicateName, Metrics/MethodLength
      changed = (calculate_digest != current_digest)
      if changed && @report_data.start_date.at_beginning_of_month < Time.zone.today.at_beginning_of_month
        business_id = @report_data.report.report_service.business_id
        start_date = @report_data.start_date
        end_date = @report_data.end_date
        template_id = @report_data.report.template_id
        DocytLib.logger.info(
          "Digest has been changed in old data, BusinessId: #{business_id}, TemplateId: #{template_id}, Start Date: #{start_date}, End Date: #{end_date}, Type: #{self.class}"
        )
      end
      changed
    end

    def current_digest
      @report_data.dependency_digests[self.class.to_s]
    end

    def calculate_digest
      raise 'Override in the child class'
    end
  end
end
