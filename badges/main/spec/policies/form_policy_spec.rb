require "rails_helper"

RSpec.describe FormPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, super_user: true }
  let(:regular_user) { build_stubbed :user, super_user: false }
  let(:persisted_form) { create :form }
  let(:new_form) { build :form }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "admin user" do
    subject { policy_for(record: persisted_form, user: admin_user) }

    it { is_expected.to be_allowed_to(:index?) }
    it { is_expected.to be_allowed_to(:show?) }
    it { is_expected.to be_allowed_to(:create?) }
    it { is_expected.to be_allowed_to(:update?) }
    it { is_expected.to be_allowed_to(:destroy?) }
  end

  describe "regular user" do
    subject { policy_for(record: persisted_form, user: regular_user) }

    it { is_expected.not_to be_allowed_to(:index?) }
    it { is_expected.not_to be_allowed_to(:show?) }
    it { is_expected.not_to be_allowed_to(:create?) }
    it { is_expected.not_to be_allowed_to(:update?) }
    it { is_expected.not_to be_allowed_to(:destroy?) }
  end

  describe "#destroy?" do
    context "with non-persisted record" do
      subject { policy_for(record: new_form, user: admin_user) }

      it { is_expected.not_to be_allowed_to(:destroy?) }
    end
  end
end
