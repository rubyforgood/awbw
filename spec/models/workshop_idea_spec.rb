require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea, org_credited: false, credits_creator: true

  # An idea nobody named an author on still credits its submitter, who filled the form in.
  describe "#author_credit" do
    it "credits the creating user's person, not the generic label" do
      creator = create(:user, :with_person)
      idea = create(:workshop_idea, created_by: creator)

      expect(idea.author_credit).to eq(creator.person.name)
      expect(WorkshopIdea.by_credited_person_name(creator.person.first_name)).to include(idea)
    end

    it "falls back to the generic label when the creator has no person" do
      idea = create(:workshop_idea, created_by: create(:user, person: nil))

      expect(idea.author_credit).to eq("AWBW Facilitator")
    end
  end

  describe ".author_name" do
    it "finds an idea by its credited author's first name" do
      idea = create(:workshop_idea, author: create(:person, first_name: "Marguerite", last_name: "Enterer"))

      expect(WorkshopIdea.author_name("Marguerite")).to include(idea)
    end

    it "finds an idea by its credited author's full name" do
      idea = create(:workshop_idea, author: create(:person, first_name: "Marguerite", last_name: "Enterer"))

      expect(WorkshopIdea.author_name("Marguerite Enterer")).to include(idea)
    end

    it "finds an idea by its submitter's name when no author is named" do
      idea = create(:workshop_idea, title: "Unnamed author", author: nil,
                                    created_by: create(:user, person: create(:person, first_name: "Marguerite", last_name: "Enterer")))

      expect(WorkshopIdea.author_name("Marguerite")).to include(idea)
    end

    it "excludes ideas credited to someone else" do
      idea = create(:workshop_idea, title: "Marguerite's idea", author: create(:person, first_name: "Marguerite", last_name: "Enterer"))
      other = create(:workshop_idea, title: "Bartholomew's idea", author: create(:person, first_name: "Bartholomew", last_name: "Elsewhere"))

      results = WorkshopIdea.author_name("Marguerite")

      expect(results).to include(idea)
      expect(results).not_to include(other)
    end
  end
end
