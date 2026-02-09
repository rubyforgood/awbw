# spec/models/concerns/name_filterable_spec.rb
require "rails_helper"

RSpec.describe NameFilterable do
  let!(:youth)   { create(:sector, name: "Youth") }
  let!(:healing) { create(:sector, name: "Healing Arts") }
  let!(:therapy) { create(:sector, name: "Therapy") }
  let!(:other)   { create(:sector, name: "Adults") }

  describe ".names" do
    it "returns all when param is not provided" do
      expect(Sector.names(nil)).to match_array([ youth, healing, therapy, other ])
    end

    it "returns none when param is provided but empty" do
      expect(Sector.names("")).to be_empty
    end

    it "matches case-insensitively" do
      expect(Sector.names("youth")).to include(youth)
    end

    it "matches exact names only (case-insensitive)" do
      expect(Sector.names("healing arts")).to include(healing)
      expect(Sector.names("HEALING ARTS")).to include(healing)
    end

    it "does NOT match partial/substring names" do
      expect(Sector.names("heal")).not_to include(healing)
      expect(Sector.names("he")).not_to include(healing, therapy)
      expect(Sector.names("the")).not_to include(therapy, other)
    end

    it "supports multiple exact names separated by --" do
      result = Sector.names("youth--healing arts")
      expect(result).to match_array([ youth, healing ])
    end

    it "does not include non-matching records" do
      expect(Sector.names("youth")).not_to include(other)
    end
  end
end
