# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersQuery do
  before do
    allow(DocytServerClient::UserApi).to receive(:new).and_return(users_api_instance)
  end

  let(:user) { Struct.new(:id) }
  let(:user_response) { instance_double(DocytServerClient::User, id: 111) }
  let(:users_response) { Struct.new(:users).new([user_response]) }
  let(:users_api_instance) { instance_double(DocytServerClient::UserApi, get_by_ids: users_response) }

  describe '#by_ids' do
    it 'get users by ids' do
      users = described_class.new.by_ids(user_ids: [111])
      expect(users.size).to eq(1)
    end
  end
end
