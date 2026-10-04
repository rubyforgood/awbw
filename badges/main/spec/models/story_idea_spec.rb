require "rails_helper"

RSpec.describe StoryIdea, type: :model do
  it_behaves_like "author_creditable", factory: :story_idea, org_credited: false, credits_creator: true

  describe "a second author" do
    let(:first_author) { create(:person, first_name: "Ada", last_name: "Lovelace", display_name_preference: "full_name") }
    let(:second_author) { create(:person, first_name: "Grace", last_name: "Hopper", display_name_preference: "full_name") }

    def two_author_idea(**attrs)
      create(:story_idea, author: first_author, co_author: second_author,
                          author_credit_preference: "full_name", co_author_credit_preference: "full_name", **attrs)
    end

    it "joins both named authors in #author_credit" do
      expect(two_author_idea.author_credit).to eq("Ada Lovelace and Grace Hopper")
    end

    it "drops the anonymous co-author and shows only the first author" do
      idea = two_author_idea(co_author_credit_preference: "anonymous")
      expect(idea.author_credit).to eq("Ada Lovelace")
    end

    it "rejects the same person as both authors" do
      idea = build(:story_idea, author: first_author, co_author: first_author)
      expect(idea).not_to be_valid
      expect(idea.errors[:co_author_id]).to be_present
    end

    it "rejects a second author with no first author" do
      idea = build(:story_idea, author: nil, co_author: second_author)
      expect(idea).not_to be_valid
      expect(idea.errors[:author_id]).to be_present
    end

    it "rejects an invalid co-author credit preference" do
      idea = build(:story_idea, author: first_author, co_author: second_author, co_author_credit_preference: "sideways")
      expect(idea).not_to be_valid
      expect(idea.errors[:co_author_credit_preference]).to be_present
    end

    it "snapshots the co-author's profile preference on create" do
      second_author.update!(display_name_preference: "first_name_only")
      idea = create(:story_idea, author: first_author, co_author: second_author, co_author_credit_preference: nil)
      expect(idea.reload.co_author_credit_preference).to eq("first_name_only")
    end

    it "filters to ideas by either author via authored_by" do
      idea = two_author_idea
      expect(StoryIdea.authored_by(second_author.id)).to include(idea)
      expect(StoryIdea.authored_by(first_author.id)).to include(idea)
    end

    it "lists the idea under the co-author via credited_to_person" do
      idea = two_author_idea
      expect(StoryIdea.credited_to_person(second_author)).to include(idea)
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
      idea = create(:story_idea, workshop: nil, external_workshop_title: nil)
      expect(idea.workshop_title).to be_nil
    end

    it "returns nil when external_workshop_title is blank" do
      idea = create(:story_idea, workshop: nil, external_workshop_title: "")
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
      idea = create(:story_idea, workshop: nil, external_workshop_title: nil)
      expect(idea.full_name).not_to include(":")
      expect(idea.full_name).to include(idea.author_credit)
    end
  end

  describe '.search_by_params' do
    let!(:idea_alpha) { create(:story_idea, title: 'Art Healing Journey') }
    let!(:idea_beta) { create(:story_idea, title: 'Community Impact Report') }

    it 'returns all when no params' do
      results = StoryIdea.search_by_params({})
      expect(results).to include(idea_alpha, idea_beta)
    end

    it 'filters by query matching title' do
      results = StoryIdea.search_by_params(query: 'Art Healing')
      expect(results).to include(idea_alpha)
      expect(results).not_to include(idea_beta)
    end

    it 'returns empty for non-matching query' do
      results = StoryIdea.search_by_params(query: 'nonexistent')
      expect(results).not_to include(idea_alpha, idea_beta)
    end

    it 'filters by organization_id' do
      results = StoryIdea.search_by_params(organization_id: idea_alpha.organization_id)
      expect(results).to include(idea_alpha)
      expect(results).not_to include(idea_beta)
    end

    it "filters by author_name matching the credited author" do
      author = create(:person, first_name: "Bartholomew", last_name: "Snazzlepants")
      authored = create(:story_idea, title: "Authored", author: author)

      results = StoryIdea.search_by_params(author_name: "Bartholomew")

      expect(results).to include(authored)
      expect(results).not_to include(idea_alpha, idea_beta)
    end

    it "filters by author_name matching the submitter when no author is named" do
      submitter = create(:person, first_name: "Bartholomew", last_name: "Snazzlepants")
      submitted = create(:story_idea, title: "Submitted", author: nil,
                                      created_by: create(:user, person: submitter))

      results = StoryIdea.search_by_params(author_name: "Bartholomew")

      expect(results).to include(submitted)
      expect(results).not_to include(idea_alpha, idea_beta)
    end
  end
end
