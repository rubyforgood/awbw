require "rails_helper"

RSpec.describe EventRegistrationPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }

  def policy_for(registration, user: nil)
    described_class.new(registration, user: user)
  end

  describe "#access_callouts?" do
    it "is allowed for a registration that isn't cancelled" do
      %w[ registered attended incomplete_attendance no_show transferred_out ].each do |status|
        expect(policy_for(build_stubbed(:event_registration, status:))).to be_allowed_to(:access_callouts?)
      end
    end

    it "is denied for a cancelled registration, even to an admin" do
      registration = build_stubbed(:event_registration, status: "cancelled")
      expect(policy_for(registration)).not_to be_allowed_to(:access_callouts?)
      expect(policy_for(registration, user: admin_user)).not_to be_allowed_to(:access_callouts?)
    end
  end
end
