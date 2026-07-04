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
      expect(reason).to include("financial records")
      expect(reason).to include("reverted payments still count")
    end

    it "explains a non-payment allocation such as a discount" do
      reg = create(:event_registration, status: "registered")
      discount = create(:discount)
      create(:allocation, source: discount, allocatable: reg, amount: -500)

      reason = reg.decorate.deletion_blocked_reason
      expect(reason).to include("financial records")
      expect(reason).to include("discounts")
    end

    it "still blocks (and explains) when the only payment has been reverted" do
      reg = create(:event_registration, status: "registered")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      allocation = create(:allocation, source: payment, allocatable: reg, amount: 1000)
      revert = create(:allocation, source: payment, allocatable: reg, amount: -1000)
      allocation.update!(reverted_id: revert.id)

      expect(reg.decorate.deletable?).to be(false)
      expect(reg.decorate.deletion_blocked_reason).to include("financial records")
    end

    it "explains recorded attendance" do
      reg = create(:event_registration, status: "attended")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has attendance on record."
      )
    end

    it "treats a no-show as a recorded attendance outcome" do
      reg = create(:event_registration, status: "no_show")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has attendance on record."
      )
    end

    it "explains a transfer out to another event" do
      reg = create(:event_registration, status: "transferred_out")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has a transfer to another event on record."
      )
    end

    it "is deletable (no reason) when transferred in with no allocations" do
      reg = create(:event_registration, status: "transferred_in")
      expect(reg.decorate.deletion_blocked_reason).to be_nil
    end

    it "combines both reasons when payment and attendance are present" do
      reg = create(:event_registration, status: "attended")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)

      reason = reg.decorate.deletion_blocked_reason
      expect(reason).to include("financial records")
      expect(reason).to include("attendance on record")
    end
  end
end
