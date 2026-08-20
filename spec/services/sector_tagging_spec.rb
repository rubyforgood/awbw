require "rails_helper"

RSpec.describe SectorTagging do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:primary) { create(:sector, name: "Healthcare") }
  let!(:additional) { create(:sector, name: "Education") }

  describe ".apply" do
    it "tags the person's primary + additional, and the org additional-only" do
      described_class.apply(person: person, organizations: [ organization ],
                            primary_ids: [ primary.id ], additional_ids: [ additional.id ])

      expect(person.sectorable_items.find_by(sector: primary).is_primary).to be(true)
      expect(person.sectorable_items.find_by(sector: additional).is_primary).to be(false)
      # The org gets both, all as additional — organizations have no primary.
      expect(organization.sectorable_items.pluck(:sector_id)).to contain_exactly(primary.id, additional.id)
      expect(organization.sectorable_items.where(is_primary: true)).to be_empty
    end

    it "is a no-op when no ids are given" do
      expect {
        described_class.apply(person: person, organizations: [ organization ])
      }.not_to change(SectorableItem, :count)
    end

    it "tolerates a nil organization in the list" do
      described_class.apply(person: person, organizations: [ nil ], additional_ids: [ additional.id ])
      expect(person.sectors).to include(additional)
    end
  end
end
