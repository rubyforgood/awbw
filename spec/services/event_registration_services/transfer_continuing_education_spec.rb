require "rails_helper"

RSpec.describe EventRegistrationServices::TransferContinuingEducation do
  let(:origin_event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 10_000) }
  let(:person) { create(:person) }
  let(:license) { create(:professional_license, person: person) }
  let(:source) { create(:event_registration, event: origin_event, registrant: person, status: "transferred_out") }
  let(:destination) do
    create(:event_registration, event: create(:event, ce_hours_offered: 6), registrant: person,
      transferred_from_registration: source)
  end

  def pay(ce, cents)
    create(:allocation, source: create(:payment, type: "CashPayment", amount_cents: cents, amount_cents_remaining: nil),
           allocatable: ce, amount: cents)
  end

  describe "#call splitting a source registration's CE (simple forward transfer)" do
    let!(:ce) do
      create(:continuing_education_registration, event_registration: source,
        professional_license: license, hours: 6, cost_cents: 10_000, skip_event_defaults: true)
    end

    it "leaves a paid, zero-hours stub on the source and a live record on the destination" do
      pay(ce, 4_000)

      described_class.new(transferred_out: source, destination: destination).call

      ce.reload
      expect(ce.hours).to eq(0)
      expect(ce.cost_cents).to eq(4_000)   # cost = amount already paid → nothing owed here
      expect(ce.remaining_cost).to eq(0)

      dest_ce = destination.continuing_education_registrations.sole
      expect(dest_ce.hours).to eq(6)
      expect(dest_ce.cost_cents).to eq(6_000)   # the outstanding balance carries forward
      expect(dest_ce.professional_license).to eq(license)
    end

    it "carries the full cost forward when nothing was paid at the source" do
      described_class.new(transferred_out: source, destination: destination).call

      expect(ce.reload.cost_cents).to eq(0)
      expect(destination.continuing_education_registrations.sole.cost_cents).to eq(10_000)
    end
  end

  describe "#call relocating a transfer-in reg's CE (collapse forward)" do
    let(:final) do
      create(:event_registration, event: create(:event, ce_hours_offered: 6), registrant: person,
        transferred_from_registration: source)
    end
    let!(:middle_ce) do
      create(:continuing_education_registration, event_registration: destination,
        professional_license: license, hours: 6, cost_cents: 6_000, skip_event_defaults: true)
    end

    it "moves the record to the final destination instead of splitting again" do
      pay(middle_ce, 2_000)

      described_class.new(transferred_out: destination, destination: final).call

      expect(middle_ce.reload.event_registration).to eq(final)
      expect(middle_ce.hours).to eq(6)
      expect(middle_ce.payments_sum).to eq(2_000)
      expect(final.continuing_education_registrations.reload).to eq([ middle_ce ])
    end
  end

  describe "#call transferring back to the origin (merge into the stub)" do
    let!(:stub) do
      create(:continuing_education_registration, event_registration: source,
        professional_license: license, hours: 0, cost_cents: 4_000, skip_event_defaults: true)
    end
    let!(:moved) do
      create(:continuing_education_registration, event_registration: destination,
        professional_license: license, hours: 6, cost_cents: 6_000, skip_event_defaults: true)
    end

    it "folds the moved record's hours, cost, and payments back into the stub" do
      pay(stub, 4_000)   # what was paid at the origin
      pay(moved, 1_000)  # a partial payment made after transferring

      described_class.new(transferred_out: destination, destination: source).call

      expect(ContinuingEducationRegistration.exists?(moved.id)).to be(false)
      stub.reload
      expect(stub.hours).to eq(6)
      expect(stub.cost_cents).to eq(10_000)   # 4,000 paid-stub + 6,000 carried balance
      expect(stub.payments_sum).to eq(5_000)  # both payments now on the restored record
    end
  end
end
