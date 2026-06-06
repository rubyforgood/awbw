require "rails_helper"

RSpec.describe EventDashboard do
  subject(:dashboard) { described_class.new(event) }

  context "with a populated paid event" do
    let(:event) { create(:event, cost_cents: 10_000) }

    # Two active registrants and one cancelled (which should be ignored everywhere).
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:cancelled_person) { create(:person) }

    let(:org_a) { create(:organization, name: "Alpha Org") }
    let(:org_b) { create(:organization, name: "Beta Org") }
    let(:org_c) { create(:organization, name: "Gamma Org") }
    let(:org_excluded) { create(:organization, name: "Excluded Org") }

    let(:sector1) { create(:sector, name: "Domestic Violence") }
    let(:sector2) { create(:sector, name: "Mental Health") }
    let(:sector_excluded) { create(:sector, name: "Veterans & Military") }

    let!(:reg1) do
      # Affiliation exists before registration so it is captured in the snapshot.
      create(:affiliation, person: person1, organization: org_a)
      create(:event_registration, event: event, registrant: person1, status: "registered")
    end

    let!(:reg2) do
      create(:affiliation, person: person2, organization: org_c)
      create(:event_registration, event: event, registrant: person2, status: "registered")
    end

    before do
      # Affiliation added after registration: present via active affiliations, not the snapshot.
      create(:affiliation, person: person1, organization: org_b)

      # Cancelled registration — its org/sector/state/money must be ignored.
      create(:affiliation, person: cancelled_person, organization: org_excluded)
      cancelled_reg = create(:event_registration, event: event, registrant: cancelled_person, status: "cancelled")
      create(:allocation, source: create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000),
                          allocatable: cancelled_reg, amount: 5_000)

      # Money: reg1 fully covered (payment + scholarship), reg2 partly paid.
      create(:allocation, source: create(:payment, amount_cents: 6_000, amount_cents_remaining: 6_000),
                          allocatable: reg1, amount: 6_000)
      scholarship = create(:scholarship, recipient: person1, amount_cents: 4_000)
      create(:allocation, source: scholarship, allocatable: reg1, amount: 4_000)

      create(:allocation, source: create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000),
                          allocatable: reg2, amount: 3_000)

      # Sectors on registrants (sector1 shared, sector2 unique, excluded one belongs to cancelled person).
      create(:sectorable_item, sector: sector1, sectorable: person1)
      create(:sectorable_item, sector: sector1, sectorable: person2)
      create(:sectorable_item, sector: sector2, sectorable: person2)
      create(:sectorable_item, sector: sector_excluded, sectorable: cancelled_person)

      # States from active registrant addresses; inactive address excluded.
      create(:address, addressable: person1, state: "CA", county: "Los Angeles")
      create(:address, addressable: person2, state: "NY", county: "Kings")
      create(:address, addressable: person2, state: "TX", county: "Travis", inactive: true)
      create(:address, addressable: cancelled_person, state: "FL", county: "Miami-Dade")
    end

    it "counts only active registrants" do
      expect(dashboard.registrant_count).to eq(2)
    end

    it "counts inactive (cancelled / no-show) registrations" do
      expect(dashboard.inactive_registration_count).to eq(1)
    end

    it "returns only active registrants as Person records" do
      expect(dashboard.registrants).to contain_exactly(person1, person2)
    end

    describe "money" do
      it "sums received payments across active registrations" do
        expect(dashboard.received_cents).to eq(9_000)
      end

      it "reports outstanding as the remaining cost after payments and scholarships" do
        expect(dashboard.outstanding_cents).to eq(7_000)
      end

      it "reports total as full-price value of active registrations" do
        expect(dashboard.total_cents).to eq(20_000)
      end

      it "reports registration subtotal as received plus outstanding" do
        expect(dashboard.registration_subtotal_cents).to eq(16_000)
      end

      it "reports grand total as registration subtotal plus scholarships plus cont ed" do
        expect(dashboard.grand_total_cents).to eq(20_000)
        expect(dashboard.grand_total_cents).to eq(
          dashboard.registration_subtotal_cents + dashboard.scholarship_total_cents + dashboard.cont_ed_total_cents
        )
      end

      it "is not free when the event has a cost" do
        expect(dashboard.free?).to be(false)
      end

      it "counts registrants paid in full" do
        expect(dashboard.paid_count).to eq(1)
      end

      it "counts registrants not paid in full" do
        expect(dashboard.unpaid_count).to eq(1)
      end
    end

    describe "scholarships" do
      it "sums scholarship dollars for active registrations" do
        expect(dashboard.scholarship_total_cents).to eq(4_000)
      end

      it "counts unique scholarship recipients" do
        expect(dashboard.scholarship_recipient_count).to eq(1)
      end
    end

    describe "organizations" do
      it "combines snapshot orgs and active affiliation orgs, deduped" do
        expect(dashboard.organizations).to contain_exactly(org_a, org_b, org_c)
      end

      it "counts unique organizations" do
        expect(dashboard.organization_count).to eq(3)
      end

      it "counts distinct registrants per organization" do
        expect(dashboard.organization_counts).to eq(org_a.id => 1, org_b.id => 1, org_c.id => 1)
      end

      it "returns the registrant ids tied to an organization" do
        expect(dashboard.organization_registrant_ids).to contain_exactly(person1.id, person2.id)
      end

      it "maps each organization to its registrant ids" do
        map = dashboard.organization_registrant_ids_by_org
        expect(map[org_a.id].to_a).to contain_exactly(person1.id)
        expect(map[org_b.id].to_a).to contain_exactly(person1.id)
        expect(map[org_c.id].to_a).to contain_exactly(person2.id)
      end
    end

    describe "sectors" do
      it "returns unique sectors across active registrants" do
        expect(dashboard.sectors).to contain_exactly(sector1, sector2)
      end

      it "counts distinct registrants per sector" do
        expect(dashboard.sector_counts).to eq(sector1.id => 2, sector2.id => 1)
      end

      it "returns the registrant ids that belong to a sector" do
        expect(dashboard.sector_registrant_ids).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "states" do
      it "returns unique states from active registrants' active addresses" do
        expect(dashboard.states).to eq(%w[CA NY])
      end

      it "counts distinct registrants per state" do
        expect(dashboard.state_counts).to eq("CA" => 1, "NY" => 1)
      end

      it "returns the registrant ids that have a state on file" do
        expect(dashboard.state_registrant_ids).to contain_exactly(person1.id, person2.id)
      end
    end

    describe "counties" do
      it "returns unique [ state, county ] pairs from active registrants' active addresses" do
        expect(dashboard.counties).to eq([ [ "CA", "Los Angeles" ], [ "NY", "Kings" ] ])
      end
    end
  end

  describe "money breakdown registrant lists" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:paid_person) { create(:person) }
    let(:unpaid_person) { create(:person) }
    let(:completed_person) { create(:person) }
    let(:pending_person) { create(:person) }

    let!(:paid_reg) { create(:event_registration, event: event, registrant: paid_person, status: "registered") }
    let!(:unpaid_reg) { create(:event_registration, event: event, registrant: unpaid_person, status: "registered") }
    let!(:completed_reg) { create(:event_registration, event: event, registrant: completed_person, status: "registered") }
    let!(:pending_reg) { create(:event_registration, event: event, registrant: pending_person, status: "registered") }

    before do
      create(:allocation, source: create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000),
                          allocatable: paid_reg, amount: 10_000)
      create(:allocation, source: create(:payment, amount_cents: 2_000, amount_cents_remaining: 2_000),
                          allocatable: unpaid_reg, amount: 2_000)
      completed = create(:scholarship, recipient: completed_person, amount_cents: 10_000, tasks_completed: true)
      create(:allocation, source: completed, allocatable: completed_reg, amount: 10_000)
      pending = create(:scholarship, recipient: pending_person, amount_cents: 10_000, tasks_completed: false)
      create(:allocation, source: pending, allocatable: pending_reg, amount: 0)
    end

    it "lists registrants paid in full (including scholarship-covered)" do
      expect(dashboard.paid_registrants).to contain_exactly(paid_person, completed_person)
    end

    it "lists registrants not paid in full" do
      expect(dashboard.unpaid_registrants).to contain_exactly(unpaid_person, pending_person)
    end

    it "splits scholarship dollars into completed and outstanding" do
      expect(dashboard.completed_scholarship_cents).to eq(10_000)
      expect(dashboard.outstanding_scholarship_cents).to eq(10_000)
    end

    it "lists completed scholarship recipients" do
      expect(dashboard.completed_scholarship_registrants).to contain_exactly(completed_person)
    end

    it "lists outstanding scholarship recipients" do
      expect(dashboard.outstanding_scholarship_registrants).to contain_exactly(pending_person)
    end
  end

  # Continuing-education fees are stubbed to zero until the feature (and its
  # migration) lands. The dashboard still renders the section, showing $0.
  describe "continuing-education fees (stubbed)" do
    let(:event) { create(:event, cost_cents: 10_000) }

    before do
      create(:event_registration, event: event, registrant: create(:person), status: "registered")
    end

    it "reports zero across totals, splits, and registrant lists" do
      expect(dashboard.cont_ed_total_cents).to eq(0)
      expect(dashboard.cont_ed_paid_cents).to eq(0)
      expect(dashboard.cont_ed_outstanding_cents).to eq(0)
      expect(dashboard.cont_ed_paid_count).to eq(0)
      expect(dashboard.cont_ed_unpaid_count).to eq(0)
      expect(dashboard.cont_ed_paid_registrants).to be_empty
      expect(dashboard.cont_ed_unpaid_registrants).to be_empty
    end

    it "adds nothing to the grand total" do
      expect(dashboard.grand_total_cents).to eq(
        dashboard.scholarship_total_cents + dashboard.received_cents + dashboard.outstanding_cents
      )
    end
  end

  # An outstanding scholarship (tasks not yet completed) has a zero allocation,
  # so the registration's full cost still sits in outstanding_cents. The grand
  # total must not also add the awarded amount, or it double-counts that cost
  # and climbs above the full-price total_cents.
  context "with an outstanding (unapplied) scholarship" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:recipient) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: recipient, status: "registered") }

    before do
      scholarship = create(:scholarship, recipient: recipient, amount_cents: 10_000, tasks_completed: false)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
    end

    it "still reports the awarded amount on the scholarship card headline" do
      expect(dashboard.scholarship_total_cents).to eq(10_000)
      expect(dashboard.scholarship_total_cents).to eq(
        dashboard.completed_scholarship_cents + dashboard.outstanding_scholarship_cents
      )
    end

    it "does not let the grand total exceed the full-price total" do
      expect(dashboard.grand_total_cents).to eq(dashboard.total_cents)
      expect(dashboard.grand_total_cents).to eq(10_000)
    end
  end

  context "with a free event" do
    let(:event) { create(:event, cost_cents: 0) }

    it "is free and has no total or outstanding cost" do
      expect(dashboard.free?).to be(true)
      expect(dashboard.total_cents).to eq(0)
      expect(dashboard.outstanding_cents).to eq(0)
    end
  end

  context "with no registrations" do
    let(:event) { create(:event, cost_cents: 10_000) }

    it "reports zeros and empty collections" do
      expect(dashboard.registrant_count).to eq(0)
      expect(dashboard.registrants).to be_empty
      expect(dashboard.total_cents).to eq(0)
      expect(dashboard.received_cents).to eq(0)
      expect(dashboard.outstanding_cents).to eq(0)
      expect(dashboard.scholarship_total_cents).to eq(0)
      expect(dashboard.organizations).to be_empty
      expect(dashboard.sectors).to be_empty
      expect(dashboard.states).to be_empty
    end
  end
end
