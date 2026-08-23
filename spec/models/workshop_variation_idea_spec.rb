require "rails_helper"

RSpec.describe WorkshopVariationIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_variation_idea, org_credited: false

  describe ".search_by_params" do
    it "filters by author_name matching the credited author" do
      author = create(:person, first_name: "Bartholomew", last_name: "Snazzlepants")
      authored = create(:workshop_variation_idea, author: author)
      other = create(:workshop_variation_idea)

      results = WorkshopVariationIdea.search_by_params(author_name: "Bartholomew")

      expect(results).to include(authored)
      expect(results).not_to include(other)
    end
  end
end
