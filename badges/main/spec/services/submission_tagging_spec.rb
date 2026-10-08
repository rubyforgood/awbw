require "rails_helper"

RSpec.describe SubmissionTagging do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:primary) { create(:sector, name: "Healthcare") }
  let!(:additional) { create(:sector, name: "Education") }

  describe ".apply with :tag_sectors" do
    it "tags the person's primary + additional, and the org additional-only" do
      described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_sectors,
                            primary_ids: [ primary.id ], additional_ids: [ additional.id ])

      expect(person.sectorable_items.find_by(sector: primary).is_primary).to be(true)
      expect(person.sectorable_items.find_by(sector: additional).is_primary).to be(false)
      # The org gets both, all as additional — organizations have no primary.
      expect(organization.sectorable_items.pluck(:sector_id)).to contain_exactly(primary.id, additional.id)
      expect(organization.sectorable_items.where(is_primary: true)).to be_empty
    end

    it "is a no-op when no ids are given" do
      expect {
        described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_sectors)
      }.not_to change(SectorableItem, :count)
    end

    it "tolerates a nil organization in the list" do
      described_class.apply(person: person, organizations: [ nil ], tag_with: :tag_sectors,
                            additional_ids: [ additional.id ])
      expect(person.sectors).to include(additional)
    end

    it "overwrites the person's sectors with replace_person, leaving the org's additive" do
      described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_sectors,
                            additional_ids: [ additional.id ])

      described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_sectors,
                            primary_ids: [ primary.id ], additional_ids: [ primary.id ],
                            replace_person: true)

      expect(person.sectors).to contain_exactly(primary)
      expect(organization.sectors).to contain_exactly(primary, additional)
    end
  end

  describe ".apply with :tag_age_groups" do
    let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:young) { create(:category, :published, category_type: age_type, name: "3-5") }
    let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }

    it "tags the person's primary + additional, and the org additional-only" do
      described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_age_groups,
                            primary_ids: [ young.id ], additional_ids: [ teen.id ])

      expect(person.primary_age_groups).to contain_exactly(young)
      expect(person.additional_age_groups).to contain_exactly(teen)
      expect(organization.primary_age_groups).to be_empty
      expect(organization.additional_age_groups).to contain_exactly(young, teen)
    end

    # The whole point of withholding primary_ids from the org: an org aggregates
    # age groups across every member, so one member's answer must not demote the
    # groups another member (or an admin) put there.
    it "leaves an organization's own primary age group alone" do
      organization.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])

      described_class.apply(person: person, organizations: [ organization ], tag_with: :tag_age_groups,
                            primary_ids: [ young.id ], additional_ids: [])

      expect(organization.reload.primary_age_groups).to contain_exactly(teen)
      expect(organization.additional_age_groups).to contain_exactly(young)
    end
  end
end
