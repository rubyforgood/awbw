require "rails_helper"

RSpec.describe StoryIdea, type: :model do
  it_behaves_like "author_creditable", factory: :story_idea

  describe "validations" do
    context "workshop selection" do
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
    it "returns workshop title when only workshop is present" do
      workshop = create(:workshop, title: "Healing Art")
      idea = create(:story_idea, workshop: workshop, external_workshop_title: nil)
      expect(idea.workshop_title).to eq("Healing Art")
    end

    it "returns external_workshop_title when workshop is nil" do
      idea = create(:story_idea, workshop: nil, external_workshop_title: "Community Session")
      expect(idea.workshop_title).to eq("Community Session")
    end

    it "returns both joined with / when both are present" do
      workshop = create(:workshop, title: "Healing Art")
      idea = create(:story_idea, workshop: workshop, external_workshop_title: "Community Session")
      expect(idea.workshop_title).to eq("Healing Art / Community Session")
    end

    it "returns nil when both workshop and external_workshop_title are absent" do
      idea = build(:story_idea, workshop: nil, external_workshop_title: nil)
      expect(idea.workshop_title).to be_nil
    end

    it "returns nil when external_workshop_title is blank" do
      idea = build(:story_idea, workshop: nil, external_workshop_title: "")
      expect(idea.workshop_title).to be_nil
    end
  end

  describe "#full_name" do
    it "includes workshop title when present" do
      workshop = create(:workshop, title: "Healing Art")
      idea = create(:story_idea, workshop: workshop)
      expect(idea.full_name).to include(": Healing Art")
    end

    it "omits workshop section when no workshop or external title" do
      idea = create(:story_idea, workshop: nil, external_workshop_title: "Temp")
      idea.update_column(:external_workshop_title, nil)
      idea.reload
      expect(idea.full_name).not_to include(":")
      expect(idea.full_name).to include(idea.author_credit)
    end
  end

  describe ".search_by_params" do
    let!(:idea_alpha) { create(:story_idea, title: "Art Healing Journey") }
    let!(:idea_beta) { create(:story_idea, title: "Community Impact Report") }

    it "returns all when no params" do
      results = StoryIdea.search_by_params({})
      expect(results).to include(idea_alpha, idea_beta)
    end

    it "filters by query matching title" do
      results = StoryIdea.search_by_params(query: "Art Healing")
      expect(results).to include(idea_alpha)
      expect(results).not_to include(idea_beta)
    end

    it "returns empty for non-matching query" do
      results = StoryIdea.search_by_params(query: "nonexistent")
      expect(results).not_to include(idea_alpha, idea_beta)
    end

    it 'filters by organization_id' do
      results = StoryIdea.search_by_params(organization_id: idea_alpha.organization_id)
      expect(results).to include(idea_alpha)
      expect(results).not_to include(idea_beta)
    end
  end
end
