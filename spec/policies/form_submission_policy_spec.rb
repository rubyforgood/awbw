require "rails_helper"

RSpec.describe FormSubmissionPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:submission) { build_stubbed :form_submission }

  def policy_for(user:, record: submission)
    described_class.new(record, user: user)
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end
end
