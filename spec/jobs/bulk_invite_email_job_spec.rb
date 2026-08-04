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
end
