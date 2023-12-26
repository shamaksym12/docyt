# frozen_string_literal: true

class SyncReportServicesService
  include DocytLib::Utils::DocytInteractor
  include DocytLib::Async::Publisher

  def sync
    ReportService.where(active: true).each do |report_service|
      next unless report_service.has_active_subscription?

      publish(events.refresh_report_datas(report_service_id: report_service.id.to_s))
    end
  end
end
