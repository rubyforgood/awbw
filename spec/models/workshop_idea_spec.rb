require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea

  describe ".pending_review" do
    it "includes ideas that have not been promoted to a workshop" do
      idea = create(:workshop_idea)
      expect(WorkshopIdea.pending_review).to include(idea)
    end

    it "excludes ideas that have been promoted to a workshop" do
      idea = create(:workshop_idea)
      create(:workshop, workshop_idea: idea)
      expect(WorkshopIdea.pending_review).not_to include(idea)
    end
  end
end
