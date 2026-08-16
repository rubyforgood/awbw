require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea

  # No author_id column, so the creator is the only credit an idea can carry.
  describe "#author_credit" do
    it "credits the creating user's person" do
      creator = create(:user, :with_person)
      idea = create(:workshop_idea, created_by: creator)

      expect(idea.author_credit).to eq(creator.person.full_name)
      expect(WorkshopIdea.by_credited_person_name(creator.person.first_name)).to include(idea)
    end
  end
end
