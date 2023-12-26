# frozen_string_literal: true

class BaseService
  include DocytLib::Utils::DocytInteractor

  protected

  def get_business(report_service)
    business_api_instance = DocytServerClient::BusinessApi.new
    business_api_instance.get_business(report_service.business_id).business
  end

  def fetch_bookkeeping_start_date(report_service)
    response = get_business(report_service)
    @bookkeeping_start_date = response.bookkeeping_start_date.to_date
  end

  def fetch_business_information(report_service)
    fetch_all_business_chart_of_accounts(business_id: report_service.business_id)
    fetch_accounting_classes(business_id: report_service.business_id)
  end

  def fetch_business_chart_of_accounts(chart_of_account_ids:, business_id:)
    business_api_instance = DocytServerClient::BusinessApi.new
    response = business_api_instance.get_business_chart_of_accounts({ chart_of_account_ids: chart_of_account_ids }, business_id)
    @business_chart_of_accounts = response.business_chart_of_accounts
  end

  def fetch_all_business_chart_of_accounts(business_id:)
    business_api_instance = DocytServerClient::BusinessApi.new
    response = business_api_instance.get_all_business_chart_of_accounts(business_id)
    @all_business_chart_of_accounts = response.business_chart_of_accounts
  end

  def fetch_business_chart_of_accounts_by_params(business_id:, display_name:, acc_type:)
    business_api_instance = DocytServerClient::BusinessApi.new
    response = business_api_instance.search_business_chart_of_accounts(business_id, display_name, acc_type)
    @business_chart_of_accounts = response.business_chart_of_accounts
  end

  def fetch_accounting_classes(business_id:)
    business_api_instance = DocytServerClient::BusinessApi.new
    response = business_api_instance.get_accounting_classes(business_id)
    @accounting_classes = response.accounting_classes
  end

  def fetch_business_vendors(business_id:)
    business_api_instance = DocytServerClient::BusinessApi.new
    response = business_api_instance.get_all_business_vendors(business_id)
    @business_vendors = response.business_vendors
  end

  def fetch_multi_business_report(current_user:)
    multi_business_service_api_instance = DocytServerClient::MultiBusinessReportServiceApi.new
    multi_business_service_api_instance.get_by_user_id(current_user.id)
  end

  def fetch_accessible_report_services(current_user:, standard_category_ids:)
    report_service_api_instance = DocytServerClient::ReportServiceApi.new
    response = report_service_api_instance.accessible_by_user_id({ standard_category_ids: standard_category_ids }, current_user.id)
    response.report_services
  end

  # service_id means ID of ReportService in DocytServer
  def fetch_business_advisors(service_ids)
    business_advisor_api_instance = DocytServerClient::BusinessAdvisorApi.new
    response = business_advisor_api_instance.get_by_ids({ ids: service_ids })
    response.business_advisors
  end

  # service_id means ID of ReportService in DocytServer
  def get_businesses(service_ids)
    business_advisors = fetch_business_advisors(service_ids)
    business_ids = business_advisors.map(&:business_id)
    business_api_instance = DocytServerClient::BusinessesApi.new
    business_api_instance.get_by_ids({ ids: business_ids }).businesses.sort_by { |business| ReportService.find_by(business_id: business.id).id }
  end

  def get_users(user_ids:)
    user_api_instance = DocytServerClient::UserApi.new
    user_api_instance.get_by_ids({ ids: user_ids }).users
  end

  def fetch_metrics_service(business_id:)
    metrics_service_api_instance = DocytServerClient::MetricsServiceApi.new
    metrics_service_api_instance.get_by_business_id(business_id)
  end
end
