require "rails_helper"

RSpec.describe GrantDecorator, type: :decorator do
  describe "money formatting" do
    let(:grant) { create(:grant, amount_cents: 100_000).decorate }

    it "formats the donation amount" do
      expect(grant.amount).to eq("$1,000")
    end

    it "formats the remaining balance" do
      create(:scholarship, grant: grant.object, amount_cents: 40_000)
      expect(grant.remaining).to eq("$600")
    end
  end

  describe "compact picker amounts" do
    it "abbreviates thousands with one decimal, trimming trailing zeros" do
      grant = create(:grant, amount_cents: 1_000_000)
      create(:scholarship, grant:, amount_cents: 250_000)
      expect(grant.decorate.remaining_compact).to eq("$7.5k")
      expect(grant.decorate.amount_compact).to eq("$10k")
    end

    it "uses plain dollars under a thousand" do
      grant = create(:grant, amount_cents: 90_000)
      create(:scholarship, grant:, amount_cents: 15_000)
      expect(grant.decorate.remaining_compact).to eq("$750")
      expect(grant.decorate.amount_compact).to eq("$900")
    end
  end

  describe "#funds_remaining_summary" do
    it "reads as a compact remaining-of-total available summary" do
      grant = create(:grant, amount_cents: 1_000_000)
      create(:scholarship, grant:, amount_cents: 250_000)
      expect(grant.decorate.funds_remaining_summary).to eq("$7.5k of $10k available")
    end
  end

  describe "#allocation_percentage" do
    it "returns the rounded percentage awarded in scholarships" do
      grant = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant:, amount_cents: 40_000)
      expect(grant.decorate.allocation_percentage).to eq(40)
    end

    it "is zero for an empty grant" do
      grant = create(:grant, amount_cents: 0)
      expect(grant.decorate.allocation_percentage).to eq(0)
    end

    it "is 100 when fully allocated" do
      grant = create(:grant, amount_cents: 50_000)
      create(:scholarship, grant:, amount_cents: 50_000)
      expect(grant.decorate.allocation_percentage).to eq(100)
    end
  end

  describe "scholarship counts" do
    it "counts total and tasks-completed scholarships" do
      grant = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant:, amount_cents: 10_000, tasks_completed: true)
      create(:scholarship, grant:, amount_cents: 10_000, tasks_completed: true)
      create(:scholarship, grant:, amount_cents: 10_000, tasks_completed: false)

      expect(grant.decorate.scholarships_count).to eq(3)
      expect(grant.decorate.completed_scholarships_count).to eq(2)
    end
  end

  describe "#scholarships_link" do
    it "links to the event registrants index filtered to the recipients when all share one event" do
      event = create(:event, cost_cents: 100_000)
      reg1 = create(:event_registration, event:)
      reg2 = create(:event_registration, event:)
      grant = create(:grant, amount_cents: 100_000)
      [ reg1, reg2 ].each do |reg|
        s = create(:scholarship, grant:, recipient: reg.registrant, amount_cents: 10_000)
        create(:allocation, source: s, allocatable: reg, amount: 10_000)
      end

      link = grant.decorate.scholarships_link
      expect(link).to start_with("/events/#{event.id}/registrants")
      expect(link).to include("registrant_ids=")
      expect(link).to include(reg1.registrant_id.to_s)
      expect(link).to include(reg2.registrant_id.to_s)
    end

    it "falls back to the grant page when scholarships span multiple events" do
      grant = create(:grant, amount_cents: 100_000)
      2.times do
        reg = create(:event_registration, event: create(:event, cost_cents: 100_000))
        s = create(:scholarship, grant:, recipient: reg.registrant, amount_cents: 10_000)
        create(:allocation, source: s, allocatable: reg, amount: 10_000)
      end

      expect(grant.decorate.scholarships_link).to eq("/grants/#{grant.id}")
    end

    it "falls back to the grant page for grant-funded scholarships with no event" do
      grant = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant:, amount_cents: 10_000)

      expect(grant.decorate.scholarships_link).to eq("/grants/#{grant.id}")
    end
  end

  describe "#remaining_percentage" do
    it "is the complement of the allocated percentage" do
      grant = create(:grant, amount_cents: 100_000)
      create(:scholarship, grant:, amount_cents: 40_000)
      expect(grant.decorate.remaining_percentage).to eq(60)
    end

    it "is zero when fully allocated" do
      grant = create(:grant, amount_cents: 50_000)
      create(:scholarship, grant:, amount_cents: 50_000)
      expect(grant.decorate.remaining_percentage).to eq(0)
    end
  end

  describe "#fully_allocated?" do
    let(:grant) { create(:grant, amount_cents: 50_000) }

    it "is true once scholarships consume the full amount" do
      create(:scholarship, grant:, amount_cents: 50_000)
      expect(grant.decorate).to be_fully_allocated
    end

    it "is false while funds remain" do
      expect(grant.decorate).not_to be_fully_allocated
    end
  end

  describe "#legacy_scholarship_badge" do
    it "renders a Legacy scholarship pill for planned-giving grants" do
      badge = create(:grant, :planned_giving).decorate.legacy_scholarship_badge
      expect(badge).to include("Legacy scholarship")
    end

    it "renders nothing for ordinary grants" do
      expect(create(:grant).decorate.legacy_scholarship_badge).to be_nil
    end
  end

  describe "#in_memoriam_badge" do
    it "renders an In memoriam pill for in-memoriam grants" do
      badge = create(:grant, :in_memoriam).decorate.in_memoriam_badge
      expect(badge).to include("In memoriam")
    end

    it "renders nothing for grants not given in memoriam" do
      expect(create(:grant, :planned_giving).decorate.in_memoriam_badge).to be_nil
    end
  end
end
