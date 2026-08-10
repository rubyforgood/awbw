require "rails_helper"

RSpec.describe AttendeesRoster do
  let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }

  let!(:older_training) { create(:event, title: "TAC 200", facilitator_training: true, start_date: Date.new(2024, 5, 1)) }
  let!(:recent_training) { create(:event, title: "TAC 261", abbreviation: "TAC261", facilitator_training: true, start_date: Date.new(2026, 5, 1)) }
  let!(:webinar) { create(:event, title: "Open webinar", facilitator_training: false, start_date: Date.new(2025, 5, 1)) }

  let!(:older_registration) { create(:event_registration, event: older_training, registrant: person, status: "attended") }
  let!(:recent_registration) { create(:event_registration, event: recent_training, registrant: person, status: "attended") }

  # Built from a fresh relation like the controller passes it, so profile
  # associations load fresh rather than from a stale in-memory cache. The `events:`
  # scope is the index's current event filter — the roster never reaches past it.
  subject(:roster) { described_class.new(Person.where(id: person.id), events: Event.facilitator_trainings) }

  describe "#event_registrations_by_registrant" do
    before do
      # Non-training attendance is outside the events: scope; a registered-but-not-
      # attended training is outside the registrations: scope. Both are excluded.
      create(:event_registration, event: webinar, registrant: person, status: "attended")
      other_training = create(:event, facilitator_training: true, start_date: Date.new(2023, 1, 1))
      create(:event_registration, event: other_training, registrant: person, status: "registered")
    end

    it "returns only in-scope registrations, most recent event first" do
      expect(roster.event_registrations_by_registrant[person.id]).to eq([ recent_registration, older_registration ])
    end

    it "widens with the events: scope rather than hardcoding trainings" do
      all_events = described_class.new(Person.where(id: person.id), events: Event.all)

      expect(all_events.event_registrations_by_registrant[person.id].map(&:event))
        .to include(webinar)
    end

    it "narrows to a single event, so a drill-in row shows that event not a history" do
      one_event = described_class.new(Person.where(id: person.id), events: Event.where(id: recent_training.id))

      expect(one_event.event_registrations_by_registrant[person.id]).to eq([ recent_registration ])
    end
  end

  describe "scholarship linkage" do
    let!(:scholarship) { create(:scholarship, recipient: person, amount_cents: 1_000) }

    before { create(:allocation, source: scholarship, allocatable: recent_registration, amount: 1_000) }

    it "surfaces the scholarship for the recipient" do
      expect(roster.scholarship_by_recipient[person.id]).to eq(scholarship)
    end

    it "links to the most recent training where the person holds a scholarship" do
      target_event, _slug = roster.scholarship_link_target(person)
      expect(target_event).to eq(recent_training)
    end

    it "exposes the training the scholarship comes from" do
      expect(roster.scholarship_event_by_registrant[person.id]).to eq(recent_training)
    end
  end

  describe "#ce_registration_by_registrant" do
    let!(:ce_registration) { create(:continuing_education_registration, event_registration: recent_registration) }

    it "surfaces the CE registration from the most recent training with one" do
      expect(roster.ce_registration_by_registrant[person.id]).to eq(ce_registration)
    end

    it "exposes the training the CE registration comes from" do
      expect(roster.ce_event_by_registrant[person.id]).to eq(recent_training)
    end
  end

  describe "columns" do
    let(:sector) { create(:sector, name: "Healthcare") }
    let(:organization) { create(:organization, name: "Wellness Org") }

    before do
      create(:sectorable_item, sectorable: person, sector: sector, is_primary: true)
      create(:address, addressable: person, state: "CA", inactive: false)
    end

    it "maps the person's primary sector" do
      expect(roster.primary_sector_names_by_registrant[person.id]).to eq([ "Healthcare" ])
    end

    it "maps organizations linked on the person's training registrations" do
      recent_registration.event_registration_organizations.create!(organization: organization)
      expect(roster.organization_ids_by_registrant[person.id]).to eq([ organization.id ])
      expect(roster.organizations).to include(organization)
    end

    it "maps a short location label from the active address" do
      expect(roster.location_label_by_registrant[person.id]).to eq("CA")
    end

    it "lists distinct affiliation statuses in display order" do
      create(:affiliation, person: person, organization: organization, start_date: 1.year.ago, end_date: nil, inactive: false)
      create(:affiliation, person: person, organization: create(:organization), start_date: 1.month.from_now, inactive: false)
      create(:affiliation, person: person, organization: create(:organization), inactive: true)
      expect(roster.affiliation_statuses_by_registrant[person.id]).to eq([ "Active", "Upcoming", "Inactive" ])
    end
  end
end
