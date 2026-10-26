require "rails_helper"

RSpec.describe SyncMembershipSubscriptionPriceJob, type: :job do
  describe "#perform" do
    it "syncs the membership's subscription price" do
      membership = create(:membership)
      allow(Membership::SyncSubscriptionPrice).to receive(:call)

      described_class.perform_now(membership.id)

      expect(Membership::SyncSubscriptionPrice).to have_received(:call).with(membership: membership)
    end

    it "does nothing for a membership that no longer exists" do
      expect { described_class.perform_now(0) }.not_to raise_error
    end
  end
end
