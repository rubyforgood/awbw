require "rails_helper"

RSpec.describe StoryIdea, type: :model do
  describe "validations" do
    context "workshop selection" do
      let(:valid_story_idea) { create(:story_idea) }

      it "is valid with a workshop_id" do
        story_idea = create(:story_idea, external_workshop_title: nil)
        expect(story_idea).to be_persisted
        expect(story_idea.workshop).to be_present
      end

      it "is valid with external_workshop_title and no workshop" do
        story_idea = create(:story_idea,
                          workshop: nil,
                          external_workshop_title: "My External Workshop")
        expect(story_idea).to be_persisted
        expect(story_idea.external_workshop_title).to eq("My External Workshop")
      end

      it "is invalid without workshop_id or external_workshop_title" do
        story_idea = build(:story_idea,
                          workshop: nil,
                          external_workshop_title: nil)
        expect(story_idea).not_to be_valid
        expect(story_idea.errors[:base]).to include("Please select a workshop or enter an external workshop title")
      end

      it "is valid with both workshop_id and external_workshop_title" do
        story_idea = create(:story_idea,
                          external_workshop_title: "My External Workshop")
        expect(story_idea).to be_persisted
        expect(story_idea.workshop).to be_present
        expect(story_idea.external_workshop_title).to eq("My External Workshop")
      end
    end
  end

  describe "#workshop_title" do
    it "returns workshop title when workshop is set" do
      workshop = create(:workshop, title: "Art Therapy 101")
      story_idea = create(:story_idea, workshop: workshop, external_workshop_title: nil)
      expect(story_idea.workshop_title).to eq("Art Therapy 101")
    end

    it "returns external title in brackets when no workshop" do
      story_idea = create(:story_idea, workshop: nil, external_workshop_title: "Community Workshop")
      expect(story_idea.workshop_title).to eq("[Community Workshop]")
    end
  end
end
