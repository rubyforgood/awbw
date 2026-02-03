require "rails_helper"

RSpec.describe SectorPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, super_user: true }
  let(:regular_user) { build_stubbed :user, super_user: false }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#tags_index?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:tags_index?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.to be_allowed_to(:tags_index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:tags_index?) }
    end
  end
end
