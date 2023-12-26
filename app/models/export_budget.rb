# frozen_string_literal: true

class ExportBudget
  include Mongoid::Document
  include DocytLib::Async::Publisher

  field :user_id, type: Integer
  field :start_date, type: Date
  field :end_date, type: Date
  field :filter, type: Hash

  belongs_to :budget

  def request_export_budget
    publish(events.export_budget_requested(export_budget_id: id.to_s))
  end
end
