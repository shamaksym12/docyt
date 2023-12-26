# frozen_string_literal: true

class TemplatesQuery
  TEMPLATES_DIR = Rails.root.join('app/assets/jsons/templates')
  HOSPITALITY_STANDARD_CATEGORY_ID = 9

  def initialize(query_params = nil)
    @query_params = query_params || {}
  end

  def self.all_template_files
    Dir.glob(File.join(TEMPLATES_DIR, '**', '*.json'))
  end

  def template_from_json(template_json)
    { id: template_json['id'],
      name: template_json['name'],
      standard_category_ids: template_json['standard_category_ids'],
      draft: template_json['draft'],
      depends_on: template_json['depends_on'],
      rank: template_json['rank'],
      category: template_json['category'] }
  end

  def template(template_id:)
    file_path = File.join(TEMPLATES_DIR, "#{template_id}.json")
    return {} unless File.file?(file_path)

    template_json = JSON.parse(File.read(file_path))
    template_from_json(template_json)
  end

  def templates
    template_array = []
    if @query_params.key?(:standard_category_id) # For Single entity
      template_array = templates_for_single_entity
    elsif @query_params[:standard_category_ids].present? # For Multi-entity
      template_array = templates_for_multi_entity
    end
    template_array.sort_by! { |k| k[:rank] }
  end

  def templates_for_single_entity
    standard_category_id = @query_params[:standard_category_id]
    all_templates.select do |template|
      template[:standard_category_ids].nil? || template[:standard_category_ids].include?(standard_category_id.to_i)
    end
  end

  def templates_for_multi_entity # rubocop:disable Metrics/CyclomaticComplexity
    standard_category_ids = @query_params[:standard_category_ids].map(&:to_i)
    template_array = all_templates.select do |template|
      template[:standard_category_ids].nil? ||
        standard_category_ids.map { |standard_category_id| template[:standard_category_ids].include?(standard_category_id) }.any?
    end
    template_array.reject! do |template|
      template[:category] == Report::BASIC_REPORT_CATEGORY || template[:id] == Report::DEPARTMENT_REPORT.to_s || template[:id] == Report::VENDOR_REPORT.to_s
    end
  end

  def all_templates
    template_array = []
    self.class.all_template_files.each do |file_path|
      template_json = JSON.parse(File.read(file_path))
      template_array << template_from_json(template_json)
    end
    template_array.sort_by! { |k| k[:rank] }.sort_by! { |k| (k[:standard_category_ids] || [0]).first }
  end
end
