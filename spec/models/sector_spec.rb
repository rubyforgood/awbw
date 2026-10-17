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

    def tag_person(sector, is_primary: true, **affiliation_attrs)
      person = create(:person)
      create(:sectorable_item, sector: sector, sectorable: person, is_primary: is_primary)
      create(:affiliation, organization: organization, person: person, title: "Director", **affiliation_attrs)
    end

    it "includes a sector an organization's active person holds as primary" do
      sector = create(:sector, :published)
      tag_person(sector)

      expect(Sector.has_published_taggings).to include(sector)
    end

    it "excludes sectors held only as additional, by ended affiliations, or on the org itself" do
      additional = create(:sector, :published)
      former = create(:sector, :published)
      org_own = create(:sector, :published)
      tag_person(additional, is_primary: false)
      tag_person(former, end_date: 1.year.ago)
      create(:sectorable_item, sector: org_own, sectorable: organization)

      expect(Sector.has_published_taggings).not_to include(additional, former, org_own)
    end
  end
end
