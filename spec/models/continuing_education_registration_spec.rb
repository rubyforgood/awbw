require "rails_helper"

RSpec.describe ContinuingEducationRegistration, type: :model do
  describe "validations" do
    it "rejects a license that belongs to someone other than the registrant" do
      registration = create(:event_registration)
      other_license = create(:professional_license)

      ce_reg = build(:continuing_education_registration,
        event_registration: registration, professional_license: other_license)

      expect(ce_reg).not_to be_valid
      expect(ce_reg.errors[:professional_license]).to include("must belong to the registrant")
    end
  end

  describe "hours and cost defaults from the event" do
    it "defaults hours from the event's offered CE hours on create" do
      event = create(:event, ce_hours_offered: 8)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, hours: nil,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.hours).to eq(8)
    end

    it "defaults cost_cents from the event's total CE cost on create" do
      event = create(:event, ce_hours_cost_cents: 12_000)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, cost_cents: nil,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.cost_cents).to eq(12_000)
    end

    it "keeps an explicitly provided cost rather than the event default" do
      event = create(:event, ce_hours_cost_cents: 12_000)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, cost_cents: 5_000,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.cost_cents).to eq(5_000)
    end
  end

  describe "certificate" do
    def ce_reg_for(event:, status:, cost_cents: 0)
      registration = create(:event_registration, event: event, status: status)
      create(:continuing_education_registration,
        event_registration: registration, cost_cents: cost_cents,
        professional_license: create(:professional_license, person: registration.registrant))
    end

    it "is available once a CE-eligible training has ended, the registrant attended, and it's paid" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended").certificate_available?).to be(true)
    end

    it "is unavailable when the event does not grant CE" do
      event = create(:event, ce_hours_offered: 0, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended").certificate_available?).to be(false)
    end

    it "is unavailable when the registrant has not attended" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "registered").certificate_available?).to be(false)
    end

    it "is unavailable while there is a CE balance due" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended", cost_cents: 10_000).certificate_available?).to be(false)
    end

    it "records delivery via certificate_sent_at" do
      ce_reg = create(:continuing_education_registration)
      expect(ce_reg.certificate_sent?).to be(false)
      ce_reg.mark_certificate_sent!
      expect(ce_reg.certificate_sent?).to be(true)
    end
  end

  # Payment interface comes from Registerable, driven by the CE record's own
  # cost_cents. Mirrors EventRegistration's payment-method coverage.
  describe "payment interface" do
    let(:ce_reg) { create(:continuing_education_registration, cost_cents: 10_000) }

    def pay(reg, amount)
      payment = create(:payment, amount_cents: amount, amount_cents_remaining: amount)
      create(:allocation, source: payment, allocatable: reg, amount: amount)
    end

    def scholarship_for(reg, amount)
      scholarship = create(:scholarship, recipient: reg.event_registration.registrant, amount_cents: amount)
      create(:allocation, source: scholarship, allocatable: reg, amount: amount)
    end

    describe "#paid_in_full? / #paid?" do
      it "is paid when the registration is zero-cost" do
        zero = create(:continuing_education_registration, cost_cents: 0)
        expect(zero).to be_paid_in_full
        expect(zero.paid?).to be(true)
      end

      it "is paid when a scholarship covers the cost" do
        scholarship_for(ce_reg, 10_000)
        expect(ce_reg).to be_paid_in_full
      end

      it "is paid when payments cover the cost" do
        pay(ce_reg, 10_000)
        expect(ce_reg).to be_paid_in_full
      end

      it "is not paid when allocations are insufficient" do
        pay(ce_reg, 5_000)
        expect(ce_reg).not_to be_paid_in_full
      end
    end

    describe "#partially_paid?" do
      it "is false when nothing has been paid" do
        expect(ce_reg).not_to be_partially_paid
      end

      it "is true when a payment covers some but not all of the cost" do
        pay(ce_reg, 5_000)
        expect(ce_reg).to be_partially_paid
      end

      it "is false when only a scholarship covers part of the cost" do
        scholarship_for(ce_reg, 5_000)
        expect(ce_reg).not_to be_partially_paid
      end

      it "is false when paid in full" do
        pay(ce_reg, 10_000)
        expect(ce_reg).not_to be_partially_paid
      end
    end

    describe "#discounted? / #discount_sum" do
      it "are set by a discount allocation" do
        create(:allocation, source: create(:discount, amount_cents: 4_000), allocatable: ce_reg, amount: 4_000)
        expect(ce_reg).to be_discounted
        expect(ce_reg.discount_sum).to eq(4_000)
      end

      it "ignore a payment-only allocation" do
        pay(ce_reg, 4_000)
        expect(ce_reg).not_to be_discounted
        expect(ce_reg.discount_sum).to eq(0)
      end
    end

    describe "#payments_sum vs #allocations_sum" do
      it "counts cash for payments_sum and every source for allocations_sum" do
        pay(ce_reg, 4_000)
        scholarship_for(ce_reg, 3_000)
        ce_reg.reload

        expect(ce_reg.payments_sum).to eq(4_000)
        expect(ce_reg.allocations_sum).to eq(7_000)
        expect(ce_reg.remaining_cost).to eq(3_000)
      end
    end

    it "issues no per-row queries when allocations are preloaded" do
      pay(ce_reg, 10_000)
      preloaded = ContinuingEducationRegistration.includes(:allocations).find(ce_reg.id)

      queries = []
      subscriber = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        preloaded.allocations_sum
        preloaded.payments_sum
        preloaded.discounted?
        preloaded.paid_in_full?
        preloaded.partially_paid?
      end

      expect(queries).to be_empty
      expect(preloaded.paid_in_full?).to be(true)
    end
  end
end
