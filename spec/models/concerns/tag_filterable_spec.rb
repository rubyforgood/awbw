# spec/models/concerns/tag_filterable_spec.rb
require "rails_helper"

RSpec.describe TagFilterable do
  let!(:sector_youth) { create(:sector, name: "Youth") }
  let!(:sector_adult) { create(:sector, name: "Adult") }
  let!(:sector_therapy) { create(:sector, name: "Therapy") }

  let!(:category_type) { create(:category_type, name: "Theme") }
  let!(:category_healing) { create(:category, name: "Healing", category_type: category_type) }
  let!(:category_empowerment) { create(:category, name: "Empowerment", category_type: category_type) }

  let!(:workshop_1) { create(:workshop, :published) }
  let!(:workshop_2) { create(:workshop, :published) }
  let!(:workshop_3) { create(:workshop, :published) }
  let!(:workshop_4) { create(:workshop, :published) }

  before do
    create(:sectorable_item, sector: sector_youth, sectorable: workshop_1)
    create(:sectorable_item, sector: sector_adult, sectorable: workshop_1)
    create(:sectorable_item, sector: sector_adult, sectorable: workshop_2)
    create(:sectorable_item, sector: sector_therapy, sectorable: workshop_3)

    create(:categorizable_item, category: category_healing, categorizable: workshop_1)
    create(:categorizable_item, category: category_empowerment, categorizable: workshop_4)
  end

  describe ".tag_names_all" do
    it "returns all when names are blank" do
      expect(Workshop.tag_names_all(:sectors, nil).count).to eq(4)
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

    it "matches exact tag names only (no substring bleed)" do
      # Should NOT match "Adult" when searching for "ad"
      result = Workshop.tag_names_all(:sectors, "ad")
      expect(result).to be_empty
      expect(result).not_to include(workshop_1, workshop_2)
    end

    it "does not match partial tag names" do
      # Should NOT match "Therapy" when searching for "the"
      result = Workshop.tag_names_all(:sectors, "the")
      expect(result).to be_empty
      expect(result).not_to include(workshop_3)

      # Should NOT match "Youth" when searching for "you"
      result = Workshop.tag_names_all(:sectors, "you")
      expect(result).to be_empty
      expect(result).not_to include(workshop_1)
    end
  end

  describe ".sector_names_all" do
    it "uses AND logic for multiple sectors" do
      result = Workshop.sector_names_all("youth--adult")
      expect(result).to match_array([ workshop_1 ])
    end
  end

  describe ".category_names_all" do
    it "filters by a single category name" do
      result = Workshop.category_names_all("healing")
      expect(result).to match_array([ workshop_1 ])
    end

    it "matches exact category names only (no substring bleed)" do
      # Should NOT match "Healing" when searching for "heal"
      result = Workshop.category_names_all("heal")
      expect(result).to be_empty

      # Should NOT match "Empowerment" when searching for "power"
      result = Workshop.category_names_all("power")
      expect(result).to be_empty
      expect(result).not_to include(workshop_4)
    end

    it "supports multiple category names with AND logic" do
      # Create a workshop with both categories
      workshop_both = create(:workshop, :published)
      create(:categorizable_item, category: category_healing, categorizable: workshop_both)
      create(:categorizable_item, category: category_empowerment, categorizable: workshop_both)

      result = Workshop.category_names_all("healing--empowerment")
      expect(result).to match_array([ workshop_both ])
    end
  end
end
