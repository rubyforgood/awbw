require "rails_helper"

RSpec.describe InvoicePolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:invoice) { build_stubbed :invoice }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#manage?" do
    context "with admin user" do
      subject { policy_for(record: invoice, user: admin_user) }

      it { is_expected.to be_allowed_to(:manage?) }
    end

    context "with regular user" do
      subject { policy_for(record: invoice, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:manage?) }
    end
  end
end
