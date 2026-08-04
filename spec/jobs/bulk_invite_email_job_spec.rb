# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkInviteEmailJob do
  after { Current.reset }

  it "sends confirmation instructions to the user" do
    user = create(:user, :unconfirmed)

    expect_any_instance_of(User).to receive(:send_confirmation_instructions)

    described_class.perform_now(user.id)
  end

  it "sets Current.user to the sender so the invite is attributed to them" do
    user = create(:user, :unconfirmed)
    sender = create(:user)

    allow_any_instance_of(User).to receive(:send_confirmation_instructions) do |record|
      expect(Current.user).to eq(sender) if record == user
    end

    described_class.perform_now(user.id, sender_id: sender.id)
  end

  it "leaves Current.user unset when no sender is given" do
    user = create(:user, :unconfirmed)

    allow_any_instance_of(User).to receive(:send_confirmation_instructions) do |record|
      expect(Current.user).to be_nil if record == user
    end

    described_class.perform_now(user.id)
  end
end
