require "rails_helper"

RSpec.describe OrganizationServices::LinkSubmittedOrganization do
  let(:person) { create(:person, user: nil) }
  let(:organization) { create(:organization, name: "Harbor Family Shelter") }
  let(:entry) do
    {
      org_name: "Harbor Family Shelter",
      position: "Counselor",
      website: "https://harbor.example.org",
      agency_type: nil,
      address: {}
    }
  end

  describe ".call" do
    it "creates the job and Facilitator affiliations, dating the facilitator one" do
      described_class.call(person: person, organization: organization, entry: entry,
                           facilitator_training: true, training_date: Date.new(2026, 8, 14))

      titles = person.affiliations.where(organization: organization).pluck(:title, :start_date)
      expect(titles).to contain_exactly([ "Counselor", nil ], [ "Facilitator", Date.new(2026, 8, 14) ])
    end

    it "skips the Facilitator affiliation when the flow doesn't confer it" do
      described_class.call(person: person, organization: organization, entry: entry,
                           facilitator_training: false)

      expect(person.affiliations.where(organization: organization).pluck(:title)).to eq([ "Counselor" ])
    end

    it "fills blank profile fields and reports them as saved" do
      result = described_class.call(person: person, organization: organization, entry: entry,
                                    facilitator_training: true)

      expect(organization.reload.website_url).to eq("https://harbor.example.org")
      expect(result.saved.map(&:field)).to include("website_url")
      expect(result.notice(organization: organization, verb: "linked"))
        .to include("Harbor Family Shelter linked.", "Saved from the form")
    end

    it "keeps a conflicting saved value and reports it as a warning" do
      organization.update!(agency_type: "School")
      conflicting = entry.merge(agency_type: "Government Agency")

      result = described_class.call(person: person, organization: organization, entry: conflicting,
                                    facilitator_training: true)

      expect(organization.reload.agency_type).to eq("School")
      expect(result.warning(organization: organization)).to include("differ", "Government Agency")
    end

    it "returns no warning when nothing conflicts" do
      result = described_class.call(person: person, organization: organization, entry: entry,
                                    facilitator_training: true)

      expect(result.warning(organization: organization)).to be_nil
    end

    it "still creates the affiliations, untitled, when no entry describes the org" do
      described_class.call(person: person, organization: organization, entry: nil,
                           facilitator_training: true, training_date: Date.new(2026, 8, 14))

      expect(person.affiliations.where(organization: organization).pluck(:title)).to eq([ "Facilitator" ])
    end

    it "anchors the affiliation to the org's sole address when none was submitted" do
      address = create(:address, addressable: organization)

      described_class.call(person: person, organization: organization, entry: entry,
                           facilitator_training: true)

      expect(person.affiliations.where(organization: organization).pluck(:organization_address_id).uniq)
        .to eq([ address.id ])
    end
  end
end
