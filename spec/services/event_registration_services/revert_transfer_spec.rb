require "rails_helper"

RSpec.describe EventRegistrationServices::RevertTransfer do
  it "is a no-op for a registration that isn't transferred out" do
    reg = create(:event_registration, status: "registered")
    expect(described_class.call(registration: reg)).to be(false)
  end

  context "pending transfer (no destination recorded)" do
    it "restores the status held before the transfer and clears the marker" do
      reg = create(:event_registration, status: "attended")
      reg.update!(status: "transferred_out") # captures "attended" as status_before_transfer

      expect(described_class.call(registration: reg)).to be(true)
      reg.reload
      expect(reg.status).to eq("attended")
      expect(reg.status_before_transfer).to be_nil
    end

    it "falls back to registered when no prior status was captured" do
      reg = create(:event_registration, status: "transferred_out")
      reg.update_column(:status_before_transfer, nil)

      described_class.call(registration: reg)
      expect(reg.reload.status).to eq("registered")
    end
  end

  context "completed transfer (destination recorded)" do
    let(:person) { create(:person) }
    let(:origin_event) { create(:event, cost_cents: 10_000) }
    let(:dest_event) { create(:event, published: true, cost_cents: 10_000) }
    let!(:source) do
      reg = create(:event_registration, registrant: person, event: origin_event, status: "attended")
      reg.update!(status: "transferred_out")
      reg
    end
    let!(:destination) do
      create(:event_registration, registrant: person, event: dest_event,
        status: "registered", transferred_from_registration: source)
    end

    it "unlinks the destination (keeping it as a standalone reg) and restores the source status" do
      expect(described_class.call(registration: source)).to be(true)

      expect(EventRegistration.exists?(destination.id)).to be(true)
      expect(destination.reload.transferred_from_registration).to be_nil
      source.reload
      expect(source.status).to eq("attended")
      expect(source.status_before_transfer).to be_nil
    end

    it "re-merges the split CE back onto the source, restoring its hours, cost, and payments" do
      license = create(:professional_license, person: person)
      # Post-split state: source keeps a paid $40 stub; the destination carries the
      # 6 hours and the $60 outstanding balance.
      source_ce = create(:continuing_education_registration, event_registration: source,
        professional_license: license, hours: 0, cost_cents: 4_000, skip_event_defaults: true)
      create(:allocation,
        source: create(:payment, amount_cents: 4_000, amount_cents_remaining: 0),
        allocatable: source_ce, amount: 4_000)
      dest_ce = create(:continuing_education_registration, event_registration: destination,
        professional_license: license, hours: 6, cost_cents: 6_000, skip_event_defaults: true)

      described_class.call(registration: source)

      source_ce.reload
      expect(source_ce.hours).to eq(6)
      expect(source_ce.cost_cents).to eq(10_000)
      expect(source_ce.allocations_sum).to eq(4_000)
      expect(ContinuingEducationRegistration.exists?(dest_ce.id)).to be(false)
    end
  end
end
