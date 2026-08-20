require "rails_helper"

RSpec.describe RegistrationTicketCalloutPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:owner) { build_stubbed :user }
  let(:event) { build_stubbed :event, :unpublished, created_by: owner }
  let(:callout) { build_stubbed :registration_ticket_callout, event: event }

  def policy_for(user:)
    described_class.new(callout, user: user)
  end

  describe "#show?" do
    it "is allowed for anyone, even on a non-public event" do
      expect(policy_for(user: nil)).to be_allowed_to(:show?)
      expect(policy_for(user: regular_user)).to be_allowed_to(:show?)
      expect(policy_for(user: admin_user)).to be_allowed_to(:show?)
    end
  end

  describe "#update?" do
    it "is allowed only for the event's managers" do
      expect(policy_for(user: admin_user)).to be_allowed_to(:update?)
      expect(policy_for(user: owner)).to be_allowed_to(:update?)
      expect(policy_for(user: regular_user)).not_to be_allowed_to(:update?)
      expect(policy_for(user: nil)).not_to be_allowed_to(:update?)
    end
  end
end
