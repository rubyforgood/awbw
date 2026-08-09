# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkInviteEmailJob do
  it "sends confirmation instructions to the user" do
    user = create(:user, :unconfirmed)

    expect_any_instance_of(User).to receive(:send_confirmation_instructions).with(sender: nil)

    described_class.perform_now(user.id)
  end

  it "passes the sender through so the invite is attributed to them" do
    user = create(:user, :unconfirmed)
    sender = create(:user)

    expect_any_instance_of(User).to receive(:send_confirmation_instructions).with(sender: sender)

    described_class.perform_now(user.id, sender_id: sender.id)
  end

  it "sends with no sender when the sender no longer exists" do
    user = create(:user, :unconfirmed)

    expect_any_instance_of(User).to receive(:send_confirmation_instructions).with(sender: nil)

    described_class.perform_now(user.id, sender_id: -1)
  end

  # End-to-end through DeviseMailer, which is where the attribution actually lands.
  # It skips logging in the test env, so unstub that after the factories have run.
  it "logs the invite notification as sent by the sender, not the portal" do
    user = create(:user, :unconfirmed)
    sender = create(:user, first_name: "Dana", last_name: "Sender")
    allow(Rails.env).to receive(:test?).and_return(false)

    described_class.perform_now(user.id, sender_id: sender.id)

    expect(Notification.last.sender).to eq(sender)
    expect(Notification.last.decorate.sender_name).to eq("Dana Sender")
  end
end
