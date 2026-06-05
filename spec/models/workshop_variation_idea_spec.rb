require "rails_helper"

RSpec.describe WorkshopVariationIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_variation_idea

  describe ".pending_review" do
    it "includes ideas that have not been promoted to a workshop variation" do
      idea = create(:workshop_variation_idea)
      expect(WorkshopVariationIdea.pending_review).to include(idea)
    end

    it "excludes ideas that have been promoted to a workshop variation" do
      idea = create(:workshop_variation_idea)
      create(:workshop_variation, workshop_variation_idea: idea)
      expect(WorkshopVariationIdea.pending_review).not_to include(idea)
    end
  end
end
