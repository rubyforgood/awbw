# spec/models/concerns/name_filterable_spec.rb
require "rails_helper"

RSpec.describe NameFilterable do
  let!(:youth)   { create(:sector, name: "Youth") }
  let!(:healing) { create(:sector, name: "Healing Arts") }
  let!(:other)   { create(:sector, name: "Adults") }

  describe ".names" do
    it "returns none for blank input" do
      expect(Sector.names(nil)).to be_empty
      expect(Sector.names("")).to be_empty
    end

    it "matches case-insensitively" do
      expect(Sector.names("youth")).to include(youth)
    end

    it "matches partial names" do
      expect(Sector.names("heal")).to include(healing)
    end

    it "supports multiple names separated by --" do
      result = Sector.names("youth--heal")
      expect(result).to match_array([ youth, healing ])
    end

    it "does not include non-matching records" do
      expect(Sector.names("youth")).not_to include(other)
    end
  end
end
