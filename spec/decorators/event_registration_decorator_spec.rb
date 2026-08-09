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

    it "explains recorded attendance, enumerating the outcomes that count" do
      reg = create(:event_registration, status: "attended")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has an attendance outcome on record (attended, incomplete, or no-show)."
      )
    end

    it "treats a no-show as a recorded attendance outcome" do
      reg = create(:event_registration, status: "no_show")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has an attendance outcome on record (attended, incomplete, or no-show)."
      )
    end

    it "explains a transfer out to another event" do
      reg = create(:event_registration, status: "transferred_out")
      expect(reg.decorate.deletion_blocked_reason).to eq(
        "Can't be deleted — this registration has a transfer to another event."
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
      expect(reason).to include("an attendance outcome on record")
    end
  end

  describe "#ce_status_badge" do
    subject(:badge) { registration.decorate.ce_status_badge(**opts) }

    let(:registration) { create(:event_registration) }
    let(:opts) { {} }

    def add_ce(number: "LIC-1", cost_cents: 15_000)
      license = create(:professional_license, person: registration.registrant, number: number)
      create(:continuing_education_registration, event_registration: registration,
        professional_license: license, cost_cents: cost_cents)
    end

    def pay(cer, amount)
      payment = create(:payment, person: registration.registrant, amount_cents: amount, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: cer, amount: amount)
    end

    context "when CE isn't in play" do
      it { is_expected.to be_nil }
    end

    context "when a CE registration sits on a placeholder license" do
      before do
        create(:continuing_education_registration, event_registration: registration,
          professional_license: create(:professional_license, :placeholder, person: registration.registrant))
      end

      it "is an amber License # needed badge" do
        expect(badge.label).to eq("License # needed")
        expect(badge.classes).to include("amber")
      end
    end

    context "when the license is on file but unpaid" do
      before { add_ce(cost_cents: 15_000) }

      it "shows the balance due in amber" do
        expect(badge.label).to eq("$150 due")
        expect(badge.classes).to include("amber")
      end

      context "with simulate_paid" do
        let(:opts) { { simulate_paid: true } }

        it "previews the blue Pending state" do
          expect(badge.label).to eq("Pending")
          expect(badge.classes).to include("blue")
        end
      end
    end

    context "when paid in full but not issued" do
      before { pay(add_ce(cost_cents: 15_000), 15_000) }

      it "is a blue Pending badge" do
        expect(badge.label).to eq("Pending")
        expect(badge.classes).to include("blue")
      end
    end

    context "when the certificate has been issued" do
      before do
        cer = add_ce(cost_cents: 15_000)
        pay(cer, 15_000)
        cer.mark_certificate_sent!
      end

      it "is a green Issued badge" do
        expect(badge.label).to eq("Issued")
        expect(badge.classes).to include("green")
      end
    end
  end

  describe "#payment_method_badge" do
    subject(:badge) { create(:event_registration, expected_payment_method: value).decorate.payment_method_badge }

    context "when no payment method is recorded" do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context "with a known method" do
      let(:value) { "Credit card (now)" }

      it "maps to its short code, icon, and classes" do
        expect(badge.code).to eq("CCN")
        expect(badge.label).to eq("Credit card (now)")
        expect(badge.classes).to include("green")
      end
    end

    context "with the buddy-system method" do
      let(:value) { "Buddy system" }

      it "maps to the BUD code" do
        expect(badge.code).to eq("BUD")
        expect(badge.classes).to include("purple")
      end
    end

    context "with an unknown / custom value" do
      let(:value) { "Wire transfer overseas" }

      it "falls back to a neutral badge showing the raw value" do
        expect(badge.label).to eq("Wire transfer overseas")
        expect(badge.classes).to include("gray")
      end
    end
  end

  describe ".payment_method_filter_options" do
    it "returns unique present values ordered by badge order, labeled with the code" do
      options = described_class.payment_method_filter_options(
        [ "Check", "Credit card (now)", "Credit card (now)", nil, "" ]
      )

      expect(options).to eq(
        [ [ "Credit card (now) (CCN)", "Credit card (now)" ], [ "Check (CK)", "Check" ] ]
      )
    end

    it "keeps unknown values last, unlabeled" do
      options = described_class.payment_method_filter_options([ "Mystery", "Check" ])

      expect(options).to eq([ [ "Check (CK)", "Check" ], [ "Mystery", "Mystery" ] ])
    end
  end

  describe "#ce_status_sort_key" do
    subject(:sort_key) { registration.decorate.ce_status_sort_key }

    let(:registration) { create(:event_registration) }

    def add_ce(placeholder: false, cost_cents: 15_000)
      license = placeholder ?
        create(:professional_license, :placeholder, person: registration.registrant) :
        create(:professional_license, person: registration.registrant)
      create(:continuing_education_registration, event_registration: registration,
        professional_license: license, cost_cents: cost_cents)
    end

    def pay(cer, amount)
      payment = create(:payment, person: registration.registrant, amount_cents: amount, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: cer, amount: amount)
    end

    context "when the certificate has been issued" do
      before do
        cer = add_ce
        pay(cer, 15_000)
        cer.mark_certificate_sent!
      end

      it { is_expected.to eq(0) }
    end

    context "when paid in full but not issued" do
      before { pay(add_ce, 15_000) }

      it { is_expected.to eq(1) }
    end

    context "when the license is on file but unpaid" do
      before { add_ce }

      it { is_expected.to eq(2) }
    end

    context "when the CE registration sits on a placeholder license" do
      before { add_ce(placeholder: true) }

      it { is_expected.to eq(3) }
    end

    context "when CE isn't in play" do
      it { is_expected.to eq(4) }
    end
  end
end
