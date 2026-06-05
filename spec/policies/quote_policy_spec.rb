require "rails_helper"

RSpec.describe QuotePolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:published_quote) { build_stubbed :quote, published: true }
  let(:unpublished_quote) { build_stubbed :quote, published: false }

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
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(record: unpublished_quote, user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with authenticated user and published quote" do
      subject { policy_for(record: published_quote, user: regular_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with authenticated user and unpublished quote" do
      subject { policy_for(record: unpublished_quote, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user and published quote" do
      subject { policy_for(record: published_quote, user: nil) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end
end
