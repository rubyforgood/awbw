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

    it "stores a blank title as nil" do
      row = create(:story_workshop, external_workshop_title: "  ")

      expect(row.external_workshop_title).to be_nil
    end
  end

  describe "one link per workshop and title" do
    let(:story) { create(:story, workshop: nil) }
    let(:workshop) { create(:workshop) }

    before { story.story_workshops.create!(workshop: workshop) }

    it "rejects the same workshop with no title twice" do
      expect(story.story_workshops.build(workshop: workshop)).not_to be_valid
    end

    it "allows the same workshop under a different title" do
      expect(story.story_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")).to be_valid
    end

    it "rejects the same workshop under a title already used" do
      story.story_workshops.create!(workshop: workshop, external_workshop_title: "Teen variant")

      expect(story.story_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")).not_to be_valid
    end

    it "rejects the same untitled workshop on a row the admin just re-pointed" do
      other = story.story_workshops.create!(workshop: create(:workshop))
      other.workshop = workshop

      expect(other).not_to be_valid
    end

    it "allows the same workshop linked to a different story" do
      expect(build(:story_workshop, story: create(:story, workshop: nil), workshop: workshop)).to be_valid
    end

    it "is backstopped by the unique index when validations are skipped" do
      duplicate = story.story_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")
      duplicate.save!
      again = story.story_workshops.build(workshop: workshop, external_workshop_title: "Teen variant")

      expect { again.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "links with no workshop" do
    let(:story) { create(:story, workshop: nil) }

    before { story.story_workshops.create!(workshop: nil, external_workshop_title: "Unlisted") }

    it "rejects a second row with the same title" do
      expect(story.story_workshops.build(workshop: nil, external_workshop_title: "Unlisted")).not_to be_valid
    end

    it "allows a second row with a different title" do
      expect(story.story_workshops.build(workshop: nil, external_workshop_title: "Another")).to be_valid
    end

    it "allows a workshop still being created to reuse that title" do
      fresh = build(:workshop)
      fresh.story_workshops.build(story_id: story.id, external_workshop_title: "Unlisted")

      expect(fresh).to be_valid
    end
  end
end
