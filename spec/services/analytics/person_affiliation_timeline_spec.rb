require "rails_helper"

RSpec.describe Analytics::PersonAffiliationTimeline do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  def affiliation(start_date:, **attrs)
    create(:affiliation, person: person, organization: organization, start_date: start_date, **attrs)
  end

  def training(start_date:, status: "attended", link_org: organization, facilitator_training: true)
    event = create(:event, facilitator_training: facilitator_training,
                           start_date: start_date, end_date: start_date + 1.day,
                           registration_close_date: start_date - 1.day)
    registration = create(:event_registration, event: event, registrant: person, status: status)
    create(:event_registration_organization, event_registration: registration, organization: link_org) if link_org
    registration
  end

  def membership_invoice(start_date:)
    membership = create(:membership, person: person)
    create(:membership_invoice, membership: membership, start_date: start_date, end_date: start_date + 1.year - 1.day)
  end

  describe "what it merges" do
    it "puts affiliations, trainings and memberships in one newest-first list" do
      affiliation(start_date: 3.years.ago.to_date)
      training(start_date: 2.years.ago)
      membership_invoice(start_date: 6.months.ago.to_date)

      entries = described_class.new(person).entries

      expect(entries.map(&:kind)).to eq([ :membership, :training, :affiliation ])
      expect(entries.map(&:occurred_at)).to eq(entries.map(&:occurred_at).sort.reverse)
    end

    it "dates a training by the event, not by when the row was written" do
      registration = training(start_date: 2.years.ago)

      entry = described_class.new(person).entries.first

      expect(entry).to be_training
      expect(entry.occurred_at.to_date).to eq(registration.event.start_date.to_date)
    end

    it "is empty for a person with no affiliations, trainings or memberships" do
      expect(described_class.new(person)).not_to be_any
    end

    it "ignores registrations to events that are not facilitator trainings" do
      training(start_date: 1.year.ago, facilitator_training: false)

      expect(described_class.new(person)).not_to be_trainings
    end
  end

  describe "#affiliated_organization_ids" do
    it "collects the organizations the person is affiliated with" do
      other = create(:organization)
      affiliation(start_date: 1.year.ago.to_date)
      create(:affiliation, person: person, organization: other, start_date: 1.year.ago.to_date)

      expect(described_class.new(person).affiliated_organization_ids).to contain_exactly(organization.id, other.id)
    end
  end

  describe "memberships" do
    it "lists the person's membership periods" do
      invoice = membership_invoice(start_date: 3.months.ago.to_date)

      timeline = described_class.new(person)

      expect(timeline).to be_memberships
      expect(timeline.entries.map(&:record)).to include(invoice)
    end
  end
end
