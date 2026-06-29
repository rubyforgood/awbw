require "rails_helper"

RSpec.describe ContinuingEducationRegistration, type: :model do
  describe "validations" do
    it "requires a known status" do
      ce_reg = build(:continuing_education_registration, status: "bogus")
      expect(ce_reg).not_to be_valid
      expect(ce_reg.errors[:status]).to be_present
    end

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
    it "defaults hours from the event's available CE hours on create" do
      event = create(:event, ce_hours_available: 8)
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

  describe "payment status" do
    it "auto-advances requested → paid once fully paid" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
      expect(ce_reg.status).to eq("requested")

      payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 10_000)

      expect(ce_reg.reload.status).to eq("paid")
      expect(ce_reg).to be_paid_in_full
    end

    it "does not clobber a later issued status" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000, status: "issued")
      payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 10_000)

      expect(ce_reg.reload.status).to eq("issued")
    end
  end

  describe "allocatable payment interface" do
    it "counts a discount as coverage toward paid_in_full?, like an event registration" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
      create(:allocation, source: create(:discount, amount_cents: 10_000), allocatable: ce_reg, amount: 10_000)

      expect(ce_reg).to be_paid_in_full
      expect(ce_reg.remaining_cost).to eq(0)
      expect(ce_reg.payments_sum).to eq(0)
    end

    it "remaining_cost subtracts all allocations and payments_sum counts only cash" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
      payment = create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 6_000)

      expect(ce_reg.remaining_cost).to eq(4_000)
      expect(ce_reg.payments_sum).to eq(6_000)
      expect(ce_reg).to be_partially_paid
    end
  end
end
