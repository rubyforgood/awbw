require "rails_helper"

RSpec.describe Analytics::AffiliationTimeline do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:affiliation) do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 1.year.ago.to_date)
  end

  def training(start_date:, status: "attended", link_org: organization, facilitator_training: true)
    event = create(:event, facilitator_training: facilitator_training,
                           start_date: start_date, end_date: start_date + 1.day,
                           registration_close_date: start_date - 1.day)
    registration = create(:event_registration, event: event, registrant: person, status: status)
    create(:event_registration_organization, event_registration: registration, organization: link_org) if link_org
    registration
  end

  def ahoy_event(name:, time:, properties: {})
    Ahoy::Event.create!(name: name, time: time, visit: create(:ahoy_visit),
                        resource_type: "Affiliation", resource_id: affiliation.id,
                        properties: properties)
  end

  describe "what it merges" do
    it "puts edits, trainings and the minting registration in one newest-first list" do
      old_training = training(start_date: 3.years.ago)
      recent_training = training(start_date: 6.months.ago)
      ahoy_event(name: "update.affiliation", time: 1.day.ago,
                 properties: { "changes" => { "end_date" => { "before" => nil, "after" => "2026-01-01" } } })

      entries = described_class.new(affiliation.reload).entries

      expect(entries.map(&:kind)).to eq([ :change, :training, :training ])
      expect(entries.map(&:occurred_at)).to eq(entries.map(&:occurred_at).sort.reverse)
      expect(entries.last.record).to eq(old_training)
      expect(entries[1].record).to eq(recent_training)
    end

    it "dates a training by the event, not by when the row was written" do
      registration = training(start_date: 2.years.ago)

      entry = described_class.new(affiliation).entries.first

      expect(entry.occurred_at.to_date).to eq(registration.event.start_date.to_date)
    end

    it "is empty for an affiliation with no history at all" do
      expect(described_class.new(affiliation)).not_to be_any
    end
  end

  describe "which trainings count as this organization's" do
    it "flags a training linked to this affiliation's organization" do
      training(start_date: 1.year.ago, link_org: organization)

      expect(described_class.new(affiliation).entries.first.linked_here).to be(true)
    end

    it "still lists a training linked to a different organization, unflagged" do
      training(start_date: 1.year.ago, link_org: create(:organization))

      entry = described_class.new(affiliation).entries.first

      expect(entry).to be_training
      expect(entry.linked_here).to be(false)
    end

    it "ignores registrations to events that are not facilitator trainings" do
      training(start_date: 1.year.ago, facilitator_training: false)

      expect(described_class.new(affiliation)).not_to be_trainings
    end
  end

  describe "the minting registration" do
    it "marks the training that created this affiliation rather than repeating it" do
      registration = training(start_date: 1.year.ago)
      affiliation.update!(event_registration: registration)

      entries = described_class.new(affiliation.reload).entries

      expect(entries.map(&:kind)).to eq([ :training ])
      expect(entries.first.minted).to be(true)
    end

    it "does not mark the person's other trainings" do
      minting = training(start_date: 2.years.ago)
      training(start_date: 1.year.ago)
      affiliation.update!(event_registration: minting)

      entries = described_class.new(affiliation.reload).entries

      expect(entries.select(&:minted).map(&:record)).to eq([ minting ])
    end

    it "adds a provenance entry when the minting event is not a facilitator training" do
      registration = training(start_date: 1.year.ago, facilitator_training: false)
      affiliation.update!(event_registration: registration)

      entries = described_class.new(affiliation.reload).entries

      expect(entries.map(&:kind)).to eq([ :provenance ])
      expect(entries.first.record).to eq(registration)
    end
  end
end
