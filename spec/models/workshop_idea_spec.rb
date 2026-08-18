require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea

  # No author_id column, and the creator never claims authorship, so an idea always
  # falls to the generic label rather than crediting whoever entered it.
  describe "#author_credit" do
    it "credits the generic label, not the creating user's person" do
      creator = create(:user, :with_person)
      idea = create(:workshop_idea, created_by: creator)

      expect(idea.author_credit).to eq("AWBW Staff")
      expect(WorkshopIdea.by_credited_person_name(creator.person.first_name)).to be_empty
    end
  end
end
