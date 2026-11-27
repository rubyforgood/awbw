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

  describe "#account_milestones" do
    let(:sent) { Time.zone.local(2026, 11, 10, 12) }

    it "marks the next step for an invited login that hasn't confirmed" do
      user = build(:user, :unconfirmed, created_at: Time.zone.local(2026, 10, 3, 12), welcome_instructions_sent_at: sent)

      milestones = user.decorate.account_milestones

      expect(milestones.map(&:state)).to eq(%i[reached reached next pending])
      expect(milestones.map(&:label)).to eq([ "Created", "Invited", "Confirmed", "Logged in" ])
      expect(milestones.map(&:date)).to eq([ "Oct 3, 2026", "Nov 10, 2026", nil, nil ])
    end

    it "counts an undated step as reached when a later one is" do
      user = build(:user, welcome_instructions_sent_at: nil, current_sign_in_at: Time.zone.local(2026, 11, 20, 12))

      milestones = user.decorate.account_milestones

      expect(milestones.map(&:state)).to all(eq(:reached))
      expect(milestones.last.label).to eq("Current login")
      expect(milestones.last.date).to eq("Nov 20, 2026")
    end

    it "dates the last login from the latest sign-in, not the one before it" do
      user = build(:user, current_sign_in_at: Time.zone.local(2026, 11, 20, 12), last_sign_in_at: Time.zone.local(2026, 1, 2, 12))

      expect(user.decorate.account_milestones.last.date).to eq("Nov 20, 2026")
    end

    it "marks no next step when the account can't log in" do
      user = build(:user, :unconfirmed, :locked)

      expect(user.decorate.account_milestones.map(&:state)).not_to include(:next)
    end
  end

  describe "#account_stop" do
    it "is nil for a login that can sign in" do
      expect(build(:user).decorate.account_stop).to be_nil
    end

    it "counts failed logins when they locked the account" do
      user = build(:user, locked_at: Time.zone.local(2026, 11, 12, 12), failed_attempts: Devise.maximum_attempts)

      stop = user.decorate.account_stop

      expect([ stop.label, stop.date, stop.detail, stop.state ])
        .to eq([ "Locked", "Nov 12, 2026", "#{Devise.maximum_attempts} failed logins", :locked ])
    end

    it "credits staff when the account was locked by hand" do
      user = build(:user, locked_at: Time.current, failed_attempts: 0)

      expect(user.decorate.account_stop.detail).to eq("By staff")
    end

    it "ends on inactive, ahead of a lock" do
      user = build(:user, :locked, inactive: true)

      expect(user.decorate.account_stop.label).to eq("Inactive")
    end
  end

  describe "#password_reset_pending?" do
    it "is true while the reset link is still open" do
      user = build(:user, reset_password_token: "token", reset_password_sent_at: 1.day.ago)

      expect(user.decorate.password_reset_pending?).to be(true)
    end

    it "is false once the reset link has expired" do
      user = build(:user, reset_password_token: "token", reset_password_sent_at: (Devise.reset_password_within + 1.day).ago)

      expect(user.decorate.password_reset_pending?).to be(false)
    end
  end
end
