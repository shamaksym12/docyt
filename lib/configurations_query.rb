# frozen_string_literal: true

class ConfigurationsQuery
  CONFIGURATIONS_DIR = Rails.root.join('app/assets/jsons/configurations')
  FIRST_DRILLDOWN_CONFIGURATION = 'first_drill_down_columns'
  REPORT_FILTER_CONFIGURATION = 'report_filter'
  MULTI_RANGE_CONFIGURATION = 'multi_range_columns'

  def all_configurations
    configuration_array = []
    all_configuration_ids.each do |configuration_id|
      configuration_array << configuration(configuration_id: configuration_id)
    end

    configuration_array
  end

  def configuration(configuration_id:) # rubocop:disable Metrics/MethodLength
    file_path = File.join(CONFIGURATIONS_DIR, "#{configuration_id}.json")
    return {} unless File.file?(file_path)

    configuration_json = JSON.parse(File.read(file_path))
    case configuration_id
    when FIRST_DRILLDOWN_CONFIGURATION
      first_drilldown_configuration_from_json(configuration_json)
    when REPORT_FILTER_CONFIGURATION
      filter_configuration_from_json(configuration_json)
    when MULTI_RANGE_CONFIGURATION
      multi_range_configuration_from_json(configuration_json)
    end
  end

  private

  def all_configuration_ids
    [
      FIRST_DRILLDOWN_CONFIGURATION,
      REPORT_FILTER_CONFIGURATION,
      MULTI_RANGE_CONFIGURATION
    ]
  end

  def first_drilldown_configuration_from_json(configuration_json)
    { id: configuration_json['id'],
      name: configuration_json['name'],
      columns: configuration_json['columns'] }
  end

  def filter_configuration_from_json(configuration_json)
    { id: configuration_json['id'],
      report_filter: configuration_json['report_filter'] }
  end

  def multi_range_configuration_from_json(configuration_json)
    { id: configuration_json['id'],
      columns: configuration_json['columns'] }
  end
end
