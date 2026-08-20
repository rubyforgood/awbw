require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea, org_credited: false

  # With no author set the creator never claims authorship, so the idea falls to the
  # generic label rather than crediting whoever entered it.
  describe "#author_credit" do
    it "credits the generic label, not the creating user's person" do
      creator = create(:user, :with_person)
      idea = create(:workshop_idea, created_by: creator)

      expect(idea.author_credit).to eq("AWBW Facilitator")
      expect(WorkshopIdea.by_credited_person_name(creator.person.first_name)).to be_empty
    end
  end

  # An idea usually names no author, so `by_credited_person_name` can't reach the
  # submitter — the admin filter matches the submitting account directly instead.
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
