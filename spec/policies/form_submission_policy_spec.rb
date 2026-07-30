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

    context "with regular user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "abc123") }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with regular user and non-matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "wrong") }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with regular user and no slug context" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: nil, slug: "abc123") }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#ticket?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:ticket?) }
    end

    context "with regular user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "abc123") }

      it { is_expected.to be_allowed_to(:ticket?) }
    end

    context "with regular user and non-matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "wrong") }

      it { is_expected.not_to be_allowed_to(:ticket?) }
    end

    context "with regular user and no slug context" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:ticket?) }
    end

    context "with no user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: nil, slug: "abc123") }

      it { is_expected.to be_allowed_to(:ticket?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:ticket?) }
    end
  end

  describe "#receipt?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:receipt?) }
    end

    context "with regular user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "abc123") }

      it { is_expected.to be_allowed_to(:receipt?) }
    end

    context "with regular user and non-matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: regular_user, slug: "wrong") }

      it { is_expected.not_to be_allowed_to(:receipt?) }
    end

    context "with no user and matching slug" do
      let(:submission) { build_stubbed(:form_submission).tap { |s| s.slug = "abc123" } }
      subject { described_class.new(submission, user: nil, slug: "abc123") }

      it { is_expected.to be_allowed_to(:receipt?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:receipt?) }
    end
  end
end
