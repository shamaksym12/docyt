# frozen_string_literal: true

class UsersQuery < BaseService
  def by_ids(user_ids:)
    get_users(user_ids: user_ids)
  end
end
