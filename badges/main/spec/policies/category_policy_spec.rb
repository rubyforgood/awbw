require "rails_helper"

RSpec.describe CategoryPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, super_user: true }
  let(:regular_user) { build_stubbed :user, super_user: false }
  let(:persisted_category) { create :category }
  let(:new_category) { build :category }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#destroy?" do
    context "with admin user" do
      context "with persisted record" do
        subject { policy_for(record: persisted_category, user: admin_user) }

        it { is_expected.to be_allowed_to(:destroy?) }
      end

      context "with non-persisted record" do
        subject { policy_for(record: new_category, user: admin_user) }

        it { is_expected.not_to be_allowed_to(:destroy?) }
      end
    end

    context "with regular user" do
      subject { policy_for(record: persisted_category, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:destroy?) }
    end
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

      it { is_expected.to be_allowed_to(:tags_index?) }
    end
  end
end
