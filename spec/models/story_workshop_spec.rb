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
  end

  # Duplicates are rejected by Story/Workshop (which can tell a removed row from
  # a kept one) and backstopped by the unique index, not per-row.
  describe "duplicate links" do
    it "lets the unique index reject the same workshop linked to a story twice" do
      story = create(:story, workshop: nil)
      workshop = create(:workshop)
      create(:story_workshop, story: story, workshop: workshop)

      expect { create(:story_workshop, story: story, workshop: workshop) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows several external-title rows with no workshop" do
      story = create(:story, workshop: nil)
      create(:story_workshop, story: story, workshop: nil, external_workshop_title: "One")

      expect(build(:story_workshop, story: story, workshop: nil, external_workshop_title: "Two")).to be_valid
    end
  end
end
