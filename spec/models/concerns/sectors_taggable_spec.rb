require "rails_helper"

# Person is used as the host model; the concern is also mixed into Organization
# and exercised there via the registration / aggregation specs.
RSpec.describe SectorsTaggable do
  let!(:health) { create(:sector, name: "Healthcare") }
  let!(:education) { create(:sector, name: "Education") }
  let!(:housing) { create(:sector, name: "Housing") }

  let(:person) { create(:person) }

  describe "#tag_sectors" do
    it "tags the primary id as primary and the additional ids as non-primary" do
      person.tag_sectors(primary_ids: [ health.id ], additional_ids: [ education.id, housing.id ])

      expect(person.sectorable_items.find_by(sector: health).is_primary).to be true
      expect(person.sectorable_items.find_by(sector: education).is_primary).to be false
      expect(person.sectorable_items.find_by(sector: housing).is_primary).to be false
    end

    it "treats a sector named in both lists as primary" do
      person.tag_sectors(primary_ids: [ health.id ], additional_ids: [ health.id, education.id ])

      expect(person.sectorable_items.find_by(sector: health).is_primary).to be true
      expect(person.sectorable_items.find_by(sector: education).is_primary).to be false
    end

    it "demotes a prior primary the caller did not re-select, keeping one primary" do
      person.sectorable_items.create!(sector: education, is_primary: true)

      person.tag_sectors(primary_ids: [ health.id ], additional_ids: [])

      expect(person.sectorable_items.find_by(sector: health).is_primary).to be true
      expect(person.sectorable_items.find_by(sector: education).is_primary).to be false
      expect(person.sectorable_items.where(is_primary: true).count).to eq(1)
    end

    it "is additive — it leaves sectors tagged earlier in place" do
      person.tag_sectors(primary_ids: [ health.id ], additional_ids: [])
      person.tag_sectors(primary_ids: [], additional_ids: [ education.id ])

      expect(person.sectors).to include(health, education)
      expect(person.sectorable_items.find_by(sector: health).is_primary).to be true
    end

    it "promotes a sector already tagged as additional" do
      person.sectorable_items.create!(sector: health, is_primary: false)

      person.tag_sectors(primary_ids: [ health.id ], additional_ids: [])

      expect(person.sectorable_items.find_by(sector: health).is_primary).to be true
    end
  end
end
