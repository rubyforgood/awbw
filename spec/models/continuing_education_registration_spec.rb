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

  describe "hours and amount" do
    it "defaults hours from the event's available CE hours on create" do
      event = create(:event, ce_hours: 8)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, hours: nil,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.hours).to eq(8)
    end

    it "recomputes cost_cents from editable (fractional) hours on save" do
      ce_reg = create(:continuing_education_registration, hours: 6)
      expect(ce_reg.cost_cents).to eq(6 * 2500)

      ce_reg.update!(hours: 1.5)
      expect(ce_reg.cost_cents).to eq(3750)
    end

    it "prices cost_cents from the event's per-hour CE cost override" do
      event = create(:event, ce_hour_cost_cents: 4000)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, hours: 6,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.cost_cents).to eq(6 * 4000)
    end
  end

  describe "payment status" do
    it "auto-advances requested → paid once fully paid" do
      ce_reg = create(:continuing_education_registration, hours: 4)
      expect(ce_reg.status).to eq("requested")

      payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 10_000)

      expect(ce_reg.reload.status).to eq("paid")
      expect(ce_reg).to be_paid_in_full
    end

    it "does not clobber a later issued status" do
      ce_reg = create(:continuing_education_registration, hours: 4, status: "issued")
      payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 10_000)

      expect(ce_reg.reload.status).to eq("issued")
    end
  end
end
