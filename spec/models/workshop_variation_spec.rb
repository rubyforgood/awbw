require "rails_helper"

RSpec.describe WorkshopVariation do
  it_behaves_like "author_creditable", factory: :workshop_variation

  describe "associations" do
    it { should belong_to(:workshop).optional }
    it { should belong_to(:windows_type).optional }
    it { should belong_to(:created_by).class_name("User").optional }
    it { should belong_to(:workshop_variation_idea).optional }
  end

  describe "validations" do
    subject { build(:workshop_variation) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:rhino_body) }
    it { should validate_presence_of(:windows_type_id) }
    it { should validate_presence_of(:author_credit_preference) }
    it { should validate_uniqueness_of(:name).scoped_to(:workshop_id).case_insensitive }
  end

  describe ".search_by_params" do
    let!(:variation_a) { create(:workshop_variation, name: "Watercolor Technique") }
    let!(:variation_b) { create(:workshop_variation, name: "Clay Sculpting") }

    it "returns all when no params" do
      results = WorkshopVariation.search_by_params({})
      expect(results).to include(variation_a, variation_b)
    end

    it "filters by query matching name" do
      results = WorkshopVariation.search_by_params(query: "Watercolor")
      expect(results).to include(variation_a)
      expect(results).not_to include(variation_b)
    end

    it "returns empty for non-matching query" do
      results = WorkshopVariation.search_by_params(query: "nonexistent")
      expect(results).not_to include(variation_a, variation_b)
    end
  end
end
