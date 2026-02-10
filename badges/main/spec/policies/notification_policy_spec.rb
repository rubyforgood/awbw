require "rails_helper"

RSpec.describe NotificationPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user, email: "user@example.com" }
  let(:notification) { build_stubbed :notification, recipient_email: "user@example.com" }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#index?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:index?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(record: notification, user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with owner user" do
      subject { policy_for(record: notification, user: regular_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with different user" do
      let(:other_user) { build_stubbed :user, email: "other@example.com" }
      subject { policy_for(record: notification, user: other_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#resend?" do
    context "with admin user" do
      subject { policy_for(record: notification, user: admin_user) }

      it { is_expected.to be_allowed_to(:resend?) }
    end

    context "with owner user" do
      subject { policy_for(record: notification, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:resend?) }
    end

    context "with no user" do
      subject { policy_for(record: notification, user: nil) }

      it { is_expected.not_to be_allowed_to(:resend?) }
    end
  end
end
