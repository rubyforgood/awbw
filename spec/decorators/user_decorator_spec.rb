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

  describe "#last_login_label" do
    it "dates the last sign-in" do
      user = build(:user, last_sign_in_at: Time.zone.local(2026, 10, 3, 12))

      expect(user.decorate.last_login_label).to eq("Last logged in Oct 3, 2026")
    end

    it "says when the login has never signed in" do
      expect(build(:user, last_sign_in_at: nil).decorate.last_login_label).to eq("Never logged in")
    end
  end

  describe "#invited_label" do
    it "dates the invite" do
      user = build(:user, welcome_instructions_sent_at: Time.zone.local(2026, 9, 1, 12))

      expect(user.decorate.invited_label).to eq("Invited Sep 1, 2026")
    end

    it "is nil when no invite was sent" do
      expect(build(:user, welcome_instructions_sent_at: nil).decorate.invited_label).to be_nil
    end
  end
end
