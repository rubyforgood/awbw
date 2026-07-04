require "rails_helper"

RSpec.describe EventRegistrationDecorator, type: :decorator do
  describe "#deletion_blocked_reason" do
    it "returns nil for a deletable registration" do
      reg = create(:event_registration, status: "registered")
      expect(reg.decorate.deletion_blocked_reason).to be_nil
    end

    it "explains a payment allocation, noting reverted payments still count" do
      reg = create(:event_registration, status: "registered")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)

      reason = reg.decorate.deletion_blocked_reason
      expect(reason).to include("payment or scholarship records")
      expect(reason).to include("reverted payments still count")
    end

    it "still blocks (and explains) when the only payment has been reverted" do
      reg = create(:event_registration, status: "registered")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      allocation = create(:allocation, source: payment, allocatable: reg, amount: 1000)
      revert = create(:allocation, source: payment, allocatable: reg, amount: -1000)
      allocation.update!(reverted_id: revert.id)

      expect(reg.decorate.deletable?).to be(false)
      expect(reg.decorate.deletion_blocked_reason).to include("payment or scholarship records")
    end

    it "explains recorded attendance" do
      reg = create(:event_registration, status: "attended")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has attendance on record."
      )
    end

    it "combines both reasons when payment and attendance are present" do
      reg = create(:event_registration, status: "attended")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)

      reason = reg.decorate.deletion_blocked_reason
      expect(reason).to include("payment or scholarship records")
      expect(reason).to include("attendance on record")
    end
  end
end
