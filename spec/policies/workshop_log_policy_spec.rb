require "rails_helper"

RSpec.describe WorkshopLogPolicy, type: :policy do
  let(:admin_user) { build_stubbed(:user, :admin) }
  let(:owner_user) { build_stubbed(:user) }
  let(:other_user) { build_stubbed(:user) }

  let(:workshop_log) { build_stubbed(:workshop_log, created_by: owner_user) }

  def policy_for(record: workshop_log, user:)
    described_class.new(record, user: user)
  end

  describe "#edit?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with owner user" do
      subject { policy_for(user: owner_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with other user" do
      subject { policy_for(user: other_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:edit?) }
    end
  end

  describe "#update?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context "with owner user" do
      subject { policy_for(user: owner_user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context "with other user" do
      subject { policy_for(user: other_user) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end
  end
end
