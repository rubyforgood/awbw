require "rails_helper"

RSpec.describe UserDecorator do
  describe "#access_statuses" do
    it "is empty for a login that can sign in" do
      expect(build(:user).decorate.access_statuses).to eq([])
    end

    it "names every reason a login can't sign in" do
      user = build(:user, :unconfirmed, :locked, inactive: true)

      expect(user.decorate.access_statuses).to eq(%w[Inactive Locked Unconfirmed])
    end
  end
end
