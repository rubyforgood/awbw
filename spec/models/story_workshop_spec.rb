require "rails_helper"

RSpec.describe StoryWorkshop do
  describe "associations" do
    it { should belong_to(:story) }
    it { should belong_to(:workshop).optional }
  end

  describe "validations" do
    it "is valid with a workshop and no title" do
      expect(build(:story_workshop, external_workshop_title: nil)).to be_valid
    end

    it "is valid with a title and no workshop" do
      expect(build(:story_workshop, workshop: nil, external_workshop_title: "Unlisted")).to be_valid
    end

    it "is invalid with neither a workshop nor a title" do
      expect(build(:story_workshop, workshop: nil, external_workshop_title: nil)).not_to be_valid
    end

    it "rejects the same workshop linked to a story twice" do
      story = create(:story, workshop: nil)
      workshop = create(:workshop)
      create(:story_workshop, story: story, workshop: workshop)

      expect(build(:story_workshop, story: story, workshop: workshop)).not_to be_valid
    end
  end
end
