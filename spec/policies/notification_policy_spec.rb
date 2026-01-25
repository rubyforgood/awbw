# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotificationPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Notification, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:notification) { create(:notification) }

    it "allows any authenticated user" do
      policy = described_class.new(notification, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "scope" do
    let!(:user_notification) { create(:notification, recipient_email: regular_user.email) }
    let!(:other_notification) { create(:notification, recipient_email: "other@example.com") }

    it "returns all notifications for admin users" do
      policy = described_class.new(Notification, user: admin_user)
      scope = policy.apply_scope(Notification, type: :relation)
      expect(scope).to include(user_notification, other_notification)
    end

    it "returns only own notifications for regular users" do
      policy = described_class.new(Notification, user: regular_user)
      scope = policy.apply_scope(Notification, type: :relation)
      expect(scope).to include(user_notification)
      expect(scope).not_to include(other_notification)
    end
  end
end
