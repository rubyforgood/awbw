require "rails_helper"

RSpec.describe TrainingInterest, type: :model do
  describe "validations" do
    it "requires a valid status" do
      interest = build(:training_interest, status: "bogus")
      expect(interest).not_to be_valid
      expect(interest.errors[:status]).to be_present
    end

    it "rejects a second open interest for the same person and general interest" do
      person = create(:person)
      create(:training_interest, person: person, event: nil)

      dupe = build(:training_interest, person: person, event: nil)
      expect(dupe).not_to be_valid
      expect(dupe.errors[:base]).to include("already has an open interest for this training")
    end

    it "rejects a second open interest for the same person and event" do
      person = create(:person)
      event = create(:event)
      create(:training_interest, person: person, event: event)

      dupe = build(:training_interest, person: person, event: event)
      expect(dupe).not_to be_valid
    end

    it "allows open interest in both a general list and a specific event" do
      person = create(:person)
      create(:training_interest, person: person, event: nil)

      specific = build(:training_interest, person: person, event: create(:event))
      expect(specific).to be_valid
    end

    it "allows a new open interest after a prior one converted" do
      person = create(:person)
      create(:training_interest, :converted, person: person, event: nil)

      fresh = build(:training_interest, person: person, event: nil)
      expect(fresh).to be_valid
    end
  end

  describe "expressed_at" do
    it "defaults to the current time on create" do
      interest = create(:training_interest)
      expect(interest.expressed_at).to be_present
    end

    it "preserves an explicitly provided timestamp (backfill)" do
      time = 2.years.ago.change(usec: 0)
      interest = create(:training_interest, expressed_at: time)
      expect(interest.expressed_at).to be_within(1.second).of(time)
    end
  end

  describe "#general?" do
    it "is true when no event is set" do
      expect(build(:training_interest, event: nil)).to be_general
    end

    it "is false when an event is set" do
      expect(build(:training_interest, event: create(:event))).not_to be_general
    end
  end

  describe "#convert!" do
    it "moves an open interest to converted" do
      interest = create(:training_interest)
      interest.convert!
      expect(interest.reload.status).to eq("converted")
    end
  end

  describe "scopes" do
    it "filters by lifecycle and generality" do
      general = create(:training_interest, event: nil)
      converted = create(:training_interest, :converted)
      event = create(:event)
      specific = create(:training_interest, person: create(:person), event: event)

      expect(described_class.open).to include(general, specific)
      expect(described_class.open).not_to include(converted)
      expect(described_class.general).to include(general)
      expect(described_class.general).not_to include(specific)
      expect(described_class.for_event(event)).to contain_exactly(specific)
    end
  end
end
