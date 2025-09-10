# frozen_string_literal: true

require "rails_helper"

RSpec.describe(UserPermission) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:user)) }
    it { is_expected.to(belong_to(:permission)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:user_permission)).to be_valid
  #   pending("Requires functional user/permission factories and associations uncommented")
  # end
end
