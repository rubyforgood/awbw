# spec/models/concerns/tag_filterable_spec.rb
require "rails_helper"

RSpec.describe TagFilterable do
  let!(:sector_youth) { create(:sector, name: "Youth") }
  let!(:sector_adult) { create(:sector, name: "Adult") }

  let!(:workshop_1) { create(:workshop, :published) }
  let!(:workshop_2) { create(:workshop, :published) }

  before do
    create(:sectorable_item, sector: sector_youth, sectorable: workshop_1)
    create(:sectorable_item, sector: sector_adult, sectorable: workshop_1)
    create(:sectorable_item, sector: sector_adult, sectorable: workshop_2)
  end

  describe ".tag_names_all" do
    it "returns all when names are blank" do
      expect(Workshop.tag_names_all(:sectors, nil).count).to eq(2)
    end

    it "filters by a single tag name" do
      result = Workshop.tag_names_all(:sectors, "adult")
      expect(result).to match_array([ workshop_1, workshop_2 ])
    end

    it "supports multiple tag names with AND logic" do
      result = Workshop.tag_names_all(:sectors, "youth--adult")
      expect(result).to match_array([ workshop_1 ])
    end

    it "returns distinct records" do
      ids = Workshop.tag_names_all(:sectors, "youth").pluck(:id)
      expect(ids).to eq(ids.uniq)
      expect(ids.length).to eq(1)
    end
  end

  describe ".sector_names_all" do
    it "uses AND logic for multiple sectors" do
      result = Workshop.sector_names_all("youth--adult")
      expect(result).to match_array([ workshop_1 ])
    end
  end
end
