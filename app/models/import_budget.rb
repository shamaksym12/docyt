# frozen_string_literal: true

class ImportBudget
  include Mongoid::Document
  include DocytLib::Async::Publisher
  include DocytLib::StorageService::HasDocytFile

  field :user_id, type: Integer
  field :imported_file_id, type: String

  has_docyt_file :imported_file

  belongs_to :budget

  def request_import_budget
    publish(events.import_budget_requested(import_budget_id: id.to_s))
  end

  def destroy_imported_file
    storage_service = StorageServiceClient::FileApi.new
    storage_service.destroy(imported_file_id)
  end
end
