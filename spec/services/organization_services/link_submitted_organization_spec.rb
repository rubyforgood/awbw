require "rails_helper"

RSpec.describe OrganizationServices::LinkSubmittedOrganization do
  let(:person) { create(:person, user: nil) }
  let(:organization) { create(:organization, name: "Harbor Family Shelter") }
  let(:entry) do
    {
      org_name: "Harbor Family Shelter",
      position: "Counselor",
      website: "https://harbor.example.org",
      organization_type: nil,
      address: {}
    }
  end

  describe ".call" do
    it "creates the job and Facilitator affiliations, dating the facilitator one" do
      described_class.call(person: person, organization: organization, entry: entry,
                           scenario: "facilitator_training", training_date: Date.new(2026, 8, 14))

      titles = person.affiliations.where(organization: organization).pluck(:title, :start_date)
      expect(titles).to contain_exactly([ "Counselor", nil ], [ "Facilitator", Date.new(2026, 8, 14) ])
    end

    it "skips the Facilitator affiliation for scenarios that don't confer it" do
      described_class.call(person: person, organization: organization, entry: entry,
                           scenario: "non_facilitator_training")
      described_class.call(person: person, organization: organization, entry: entry,
                           scenario: nil)

      expect(person.affiliations.where(organization: organization).pluck(:title)).to eq([ "Counselor" ])
    end

    it "fills blank profile fields and reports them as saved" do
      result = described_class.call(person: person, organization: organization, entry: entry,
                                    scenario: "on_demand")

      expect(organization.reload.website_url).to eq("https://harbor.example.org")
      expect(result.saved.map(&:field)).to include("website_url")
      expect(result.notice(organization: organization, verb: "linked"))
        .to include("Harbor Family Shelter linked.", "Saved from the form")
    end

    it "keeps a conflicting saved value and reports it as a warning" do
      organization.update!(organization_type: "School")
      conflicting = entry.merge(organization_type: "Government Agency")

      result = described_class.call(person: person, organization: organization, entry: conflicting,
                                    scenario: "on_demand")

      expect(organization.reload.organization_type).to eq("School")
      expect(result.warning(organization: organization)).to include("differ", "Government Agency")
    end

    it "returns no warning when nothing conflicts" do
      result = described_class.call(person: person, organization: organization, entry: entry,
                                    scenario: "on_demand")

      expect(result.warning(organization: organization)).to be_nil
    end

    it "still creates the affiliations, untitled, when no entry describes the org" do
      described_class.call(person: person, organization: organization, entry: nil,
                           scenario: "on_demand", training_date: Date.new(2026, 8, 14))

      expect(person.affiliations.where(organization: organization).pluck(:title)).to eq([ "Facilitator" ])
    end

    it "on a new job, ends the other orgs' affiliations and starts both new ones on the submission date" do
      old_org = create(:organization, name: "Old Org")
      old_facilitator = create(:affiliation, person: person, organization: old_org, title: "Facilitator")

      described_class.call(person: person, organization: organization, entry: entry,
                           training_date: Date.new(2026, 8, 14),
                           scenario: "new_job")

      expect(old_facilitator.reload.end_date).to eq(Date.new(2026, 8, 13))
      expect(person.affiliations.where(organization: organization).pluck(:title, :start_date))
        .to contain_exactly([ "Counselor", Date.new(2026, 8, 14) ], [ "Facilitator", Date.new(2026, 8, 14) ])
    end

    it "on a reinstatement, creates a fresh Facilitator affiliation dated to the submission when the old one ended" do
      ended = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                     start_date: Date.new(2022, 3, 1), end_date: Date.new(2024, 6, 30))

      described_class.call(person: person, organization: organization, entry: entry,
                           training_date: Date.new(2026, 8, 14),
                           scenario: "reinstatement")

      expect(ended.reload.end_date).to eq(Date.new(2024, 6, 30))
      facilitators = person.affiliations.facilitators.where(organization: organization).order(:start_date)
      expect(facilitators.map(&:start_date)).to eq([ Date.new(2022, 3, 1), Date.new(2026, 8, 14) ])
      expect(facilitators.last).to be_active
    end

    it "on a reinstatement, leaves an already-active Facilitator affiliation alone and adds nothing" do
      active = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                      start_date: Date.new(2022, 3, 1))

      described_class.call(person: person, organization: organization, entry: entry,
                           training_date: Date.new(2026, 8, 14),
                           scenario: "reinstatement")

      expect(active.reload.end_date).to be_nil
      expect(person.affiliations.facilitators.where(organization: organization).count).to eq(1)
    end

    it "anchors the affiliation to the org's sole address when none was submitted" do
      address = create(:address, addressable: organization)

      described_class.call(person: person, organization: organization, entry: entry,
                           scenario: "on_demand")

      expect(person.affiliations.where(organization: organization).pluck(:organization_address_id).uniq)
        .to eq([ address.id ])
    end
  end
end
