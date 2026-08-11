require "rails_helper"

RSpec.describe PersonInviter do
  # Referenced up front so lazily creating the admin doesn't skew User.count
  # assertions inside the expectation blocks below.
  let!(:sender) { create(:user, :admin) }

  describe ".call" do
    it "creates a portal account for a person who has none and sends the invite" do
      person = create(:person, user: nil, email: "newbie@example.com")

      result = nil
      expect {
        result = described_class.call(person: person, sender: sender)
      }.to change { person.reload.user }.from(nil)
        .and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(result.invited).to be(true)
      user = person.reload.user
      expect(user.email).to eq("newbie@example.com")
      expect(user.welcome_instructions_sent_at).to be_present
      expect(user.welcome_instructions_sent_by).to eq(sender)
    end

    it "invites an existing unconfirmed user without creating a second account" do
      person = create(:person, user: create(:user, :unconfirmed, email: "pending@example.com"))

      expect {
        result = described_class.call(person: person, sender: sender)
        expect(result.invited).to be(true)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
        .and change(User, :count).by(0)
    end

    it "skips a person who already has a confirmed account" do
      person = create(:person) # factory associates a confirmed user

      expect {
        result = described_class.call(person: person, sender: sender)
        expect(result.invited).to be(false)
        expect(result.reason).to eq(:already_confirmed)
      }.not_to change { ActionMailer::Base.deliveries.count }
    end

    it "skips a person with no email address" do
      person = create(:person, user: nil, email: nil, email_2: nil)

      expect {
        result = described_class.call(person: person, sender: sender)
        expect(result.invited).to be(false)
        expect(result.reason).to eq(:no_email)
      }.not_to change(User, :count)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
