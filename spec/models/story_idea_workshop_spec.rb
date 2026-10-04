require "rails_helper"

RSpec.describe StoryIdeaWorkshop do
  describe "associations" do
    it { should belong_to(:story_idea) }
    it { should belong_to(:workshop).optional }
  end

  describe "validations" do
    it "is valid with a workshop and no title" do
      expect(build(:story_idea_workshop, external_workshop_title: nil)).to be_valid
    end

    it "is valid with a title and no workshop" do
      expect(build(:story_idea_workshop, workshop: nil, external_workshop_title: "Unlisted")).to be_valid
    end

    it "is invalid with neither a workshop nor a title" do
      expect(build(:story_idea_workshop, workshop: nil, external_workshop_title: nil)).not_to be_valid
    end

    it "stores a blank title as nil" do
      row = create(:story_idea_workshop, external_workshop_title: "  ")

      expect(row.external_workshop_title).to be_nil
    end
  end

  describe "one link per workshop and title" do
    let(:story_idea) { create(:story_idea, workshop: nil) }
    let(:workshop) { create(:workshop) }

    before { story_idea.story_idea_workshops.create!(workshop: workshop) }

    it "rejects the same workshop with no title twice" do
      expect(story_idea.story_idea_workshops.build(workshop: workshop)).not_to be_valid
    end

    it "allows the same workshop under a different title" do
      expect(story_idea.story_idea_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")).to be_valid
    end

    it "rejects the same workshop under a title already used" do
      story_idea.story_idea_workshops.create!(workshop: workshop, external_workshop_title: "Teen variant")

      expect(story_idea.story_idea_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")).not_to be_valid
    end

    it "rejects the same untitled workshop on a row the admin just re-pointed" do
      other = story_idea.story_idea_workshops.create!(workshop: create(:workshop))
      other.workshop = workshop

      expect(other).not_to be_valid
    end

    it "allows the same workshop linked to a different idea" do
      expect(build(:story_idea_workshop, story_idea: create(:story_idea, workshop: nil), workshop: workshop)).to be_valid
    end

    it "is backstopped by the unique index when validations are skipped" do
      duplicate = story_idea.story_idea_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")
      duplicate.save!
      again = story_idea.story_idea_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")

      expect { again.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "links with no workshop" do
    let(:story_idea) { create(:story_idea, workshop: nil) }

    before { story_idea.story_idea_workshops.create!(workshop: nil, external_workshop_title: "Unlisted") }

    it "rejects a second row with the same title" do
      expect(story_idea.story_idea_workshops.build(workshop: nil, external_workshop_title: "Unlisted")).not_to be_valid
    end

    it "allows a second row with a different title" do
      expect(story_idea.story_idea_workshops.build(workshop: nil, external_workshop_title: "Another")).to be_valid
    end
  end
end
