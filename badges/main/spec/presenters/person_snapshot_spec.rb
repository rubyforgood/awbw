require "rails_helper"

RSpec.describe PersonSnapshot do
  let(:person) { create(:person) }

  describe "#affiliations" do
    it "keeps active and upcoming affiliations, newest first, capped at 8" do
      9.times do |i|
        create(:affiliation, person:, organization: create(:organization),
               title: "Facilitator", inactive: false, start_date: (i + 1).months.ago)
      end
      create(:affiliation, person:, organization: create(:organization),
             title: "Facilitator", start_date: 3.years.ago, end_date: 1.year.ago)

      snapshot = described_class.new(person)
      dates = snapshot.affiliations.map(&:start_date)

      expect(dates.size).to eq(8)
      expect(dates).to eq(dates.sort.reverse)
    end
  end

  describe "#affiliation_rows" do
    it "lists FA rows first with their org's JAs folded under, then JA-only orgs" do
      shared = create(:organization)
      solo = create(:organization)
      director = create(:affiliation, person:, organization: solo, title: "Director", start_date: 1.week.ago)
      fa = create(:affiliation, person:, organization: shared, title: "Facilitator", start_date: 2.months.ago)
      founder = create(:affiliation, person:, organization: shared, title: "Founder", start_date: 1.month.ago)

      rows = described_class.new(person).affiliation_rows

      expect(rows.map(&:affiliation)).to eq([ fa, director ])
      expect(rows.first.job_affiliations).to eq([ founder ])
      expect(rows.last.job_affiliations).to be_empty
    end
  end

  describe "#trainings" do
    it "includes every attendance status for facilitator trainings, newest first, capped at 8" do
      9.times do |i|
        event = create(:event, facilitator_training: true, start_date: (i + 1).months.ago)
        create(:event_registration, registrant: person, event:,
               status: i.zero? ? "no_show" : "attended")
      end
      other = create(:event, facilitator_training: false, start_date: 1.month.ago)
      create(:event_registration, registrant: person, event: other, status: "attended")

      snapshot = described_class.new(person)
      dates = snapshot.trainings.map { |registration| registration.event.start_date }

      expect(dates.size).to eq(8)
      expect(dates).to eq(dates.sort.reverse)
      expect(snapshot.trainings.map(&:status)).to include("no_show")
      expect(snapshot.trainings.map { |registration| registration.event.facilitator_training? }).to all(be(true))
    end
  end

  describe "#membership" do
    it "prefers the active membership" do
      create(:membership, person:, start_date: 2.years.ago, end_date: 1.year.ago)
      active = create(:membership, person:, start_date: Date.current, end_date: Date.current + 1.year)

      expect(described_class.new(person).membership).to eq(active)
    end

    it "is nil without memberships" do
      expect(described_class.new(person).membership).to be_nil
    end
  end

  describe "#affiliated_since" do
    it "returns the earliest affiliation start date" do
      create(:affiliation, person:, organization: create(:organization),
             start_date: Date.new(2020, 3, 1), end_date: Date.new(2021, 1, 1))
      create(:affiliation, person:, organization: create(:organization),
             start_date: Date.new(2024, 6, 1))

      expect(described_class.new(person).affiliated_since).to eq(Date.new(2020, 3, 1))
    end
  end

  describe "#affiliations_heading" do
    it "names the month the person was first affiliated" do
      create(:affiliation, person:, organization: create(:organization), start_date: Date.new(2025, 1, 1))

      expect(described_class.new(person).affiliations_heading).to eq("Affiliated since Jan 2025")
    end

    it "is plain without a start date" do
      expect(described_class.new(person).affiliations_heading).to eq("Affiliations")
    end
  end

  describe "#empty?" do
    it "is true when there are no affiliations, trainings, or membership" do
      expect(described_class.new(person).empty?).to be(true)
    end
  end
end
