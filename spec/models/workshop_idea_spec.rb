require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea, org_credited: true

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

  # Crediting nobody leaves `by_credited_person_name` empty for this model, so the
  # admin filter has to reach the submitter directly or it matches nothing at all.
  describe ".author_name" do
    let(:creator) { create(:user, :with_person) }

    before { creator.person.update!(first_name: "Marguerite", last_name: "Enterer") }

    it "finds an idea by its submitter's first name" do
      idea = create(:workshop_idea, created_by: creator)

      expect(WorkshopIdea.author_name("Marguerite")).to include(idea)
    end

    it "finds an idea by its submitter's full name" do
      idea = create(:workshop_idea, created_by: creator)

      expect(WorkshopIdea.author_name("Marguerite Enterer")).to include(idea)
    end

    it "finds an idea by the submitter's account email" do
      idea = create(:workshop_idea, created_by: creator)

      expect(WorkshopIdea.author_name(creator.email)).to include(idea)
    end

    it "excludes ideas submitted by someone else" do
      other = create(:user, :with_person)
      other.person.update!(first_name: "Bartholomew", last_name: "Elsewhere")
      create(:workshop_idea, created_by: other)

      expect(WorkshopIdea.author_name("Marguerite")).to be_empty
    end
  end
end
