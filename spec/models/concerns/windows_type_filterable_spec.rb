# spec/models/concerns/windows_type_filterable_spec.rb
require "rails_helper"

RSpec.describe WindowsTypeFilterable, type: :model do
  # Pick ONE model that includes the concern
  # Workshop is a good canonical choice
  subject(:model_class) { Workshop }

  describe ".normalize_windows_type_name" do
    it "normalizes family and combined to 'combined'" do
      expect(model_class.normalize_windows_type_name("Family")).to eq("combined")
      expect(model_class.normalize_windows_type_name("combined workshop")).to eq("combined")
    end

    it "normalizes child to 'children'" do
      expect(model_class.normalize_windows_type_name("Child")).to eq("children")
      expect(model_class.normalize_windows_type_name("children only")).to eq("children")
    end

    it "defaults to 'adult' for other values" do
      expect(model_class.normalize_windows_type_name("Adult")).to eq("adult")
      expect(model_class.normalize_windows_type_name("something else")).to eq("adult")
    end

    it "handles nil safely" do
      expect(model_class.normalize_windows_type_name(nil)).to eq("adult")
    end
  end

  describe ".windows_type_name scope" do
    let!(:adult_type)     { create(:windows_type, short_name: "Adult") }
    let!(:children_type)  { create(:windows_type, short_name: "Children") }
    let!(:combined_type)  { create(:windows_type, short_name: "Combined") }

    let!(:adult_workshop) do
      create(:workshop, :published, windows_type: adult_type)
    end

    let!(:children_workshop) do
      create(:workshop, :published, windows_type: children_type)
    end

    let!(:combined_workshop) do
      create(:workshop, :published, windows_type: combined_type)
    end

    it "returns all records when value is blank" do
      expect(model_class.windows_type_name(nil)).to match_array(
                                                      [ adult_workshop, children_workshop, combined_workshop ]
                                                    )
    end

    it "filters to combined when input includes 'family'" do
      expect(model_class.windows_type_name("family")).to contain_exactly(
                                                           combined_workshop
                                                         )
    end

    it "filters to children when input includes 'child'" do
      expect(model_class.windows_type_name("child")).to contain_exactly(
                                                          children_workshop
                                                        )
    end

    it "filters to adult for all other inputs" do
      expect(model_class.windows_type_name("adult")).to contain_exactly(
                                                          adult_workshop
                                                        )
    end

    it "is case-insensitive" do
      expect(model_class.windows_type_name("CHILDREN")).to contain_exactly(
                                                             children_workshop
                                                           )
    end
  end
end
