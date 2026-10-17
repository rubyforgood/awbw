require 'rails_helper'

RSpec.describe Sector, type: :model do
  describe ".taggings_presence" do
    let!(:tagged) { create(:sector) }
    let!(:untagged) { create(:sector) }

    before { create(:sectorable_item, sector: tagged) }

    it "returns only sectors with taggings for \"with\"" do
      expect(Sector.taggings_presence("with")).to contain_exactly(tagged)
    end

    it "returns only sectors without taggings for \"without\"" do
      expect(Sector.taggings_presence("without")).to contain_exactly(untagged)
    end

    it "returns all sectors for a blank value" do
      expect(Sector.taggings_presence("")).to contain_exactly(tagged, untagged)
    end
  end

  describe "#stories" do
    it "returns stories tagged with the sector" do
      sector = create(:sector, :published)
      story = create(:story)
      story.sectorable_items.create!(sector: sector)

      expect(sector.stories).to contain_exactly(story)
    end
  end

  describe ".story_share_featured" do
    it "returns only sectors with a position, ordered by it" do
      third = create(:sector, story_share_position: 3)
      first = create(:sector, story_share_position: 1)
      create(:sector, story_share_position: nil)

      expect(Sector.story_share_featured).to eq([ first, third ])
    end
  end

  describe ".has_published_taggings" do
    let(:organization) { create(:organization) }

    def tag_person(sector, **affiliation_attrs)
      person = create(:person)
      create(:sectorable_item, sector: sector, sectorable: person, is_primary: true)
      create(:affiliation, organization: organization, person: person, **affiliation_attrs)
    end

    it "includes a sector an organization's active facilitator holds as primary" do
      sector = create(:sector, :published)
      tag_person(sector)

      expect(Sector.has_published_taggings).to include(sector)
    end

    it "excludes sectors held only by non-facilitators, by ended affiliations, or on the org itself" do
      staff_only = create(:sector, :published)
      former = create(:sector, :published)
      org_own = create(:sector, :published)
      tag_person(staff_only, title: "Director")
      tag_person(former, end_date: 1.year.ago)
      create(:sectorable_item, sector: org_own, sectorable: organization)

      expect(Sector.has_published_taggings).not_to include(staff_only, former, org_own)
    end
  end
end
