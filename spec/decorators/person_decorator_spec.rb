require "rails_helper"

RSpec.describe PersonDecorator do
  describe "#active_facilitator_organization_names" do
    let(:person) { create(:person) }

    it "returns sorted, unique org names for active facilitator affiliations" do
      beta = create(:organization, name: "Beta Org")
      alpha = create(:organization, name: "Alpha Org")
      create(:affiliation, person: person, organization: beta, title: "Facilitator")
      create(:affiliation, person: person, organization: alpha, title: "Facilitator")

      expect(person.decorate.active_facilitator_organization_names).to eq([ "Alpha Org", "Beta Org" ])
    end

    it "excludes non-facilitator affiliations" do
      org = create(:organization, name: "Board Org")
      create(:affiliation, person: person, organization: org, title: "Board Member")

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end

    it "excludes expired facilitator affiliations" do
      org = create(:organization, name: "Past Org")
      create(:affiliation, person: person, organization: org, title: "Facilitator", end_date: 1.day.ago)

      expect(person.decorate.active_facilitator_organization_names).to be_empty
    end
  end

  describe "#affiliated_since_date" do
    let(:person) { create(:person) }

    it "returns the earliest affiliation start date" do
      create(:affiliation, person: person, start_date: Date.new(2024, 5, 1))
      create(:affiliation, person: person, start_date: Date.new(2022, 3, 1))
      create(:affiliation, person: person, start_date: Date.new(2023, 8, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2022, 3, 1))
    end

    it "ignores affiliations without a start date" do
      create(:affiliation, person: person, start_date: nil)
      create(:affiliation, person: person, start_date: Date.new(2021, 1, 1))

      expect(person.decorate.affiliated_since_date).to eq(Date.new(2021, 1, 1))
    end

    it "is nil when there are no affiliations with a start date" do
      create(:affiliation, person: person, start_date: nil)

      expect(person.decorate.affiliated_since_date).to be_nil
    end
  end
end
