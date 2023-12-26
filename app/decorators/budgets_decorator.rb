# frozen_string_literal: true

class BudgetsDecorator < Draper::Decorator
  delegate_all

  def creator_name
    creator = context[:users].detect { |user| user.id == object.creator_id }
    creator&.parsed_fullname
  end
end
