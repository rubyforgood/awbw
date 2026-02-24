require "rails_helper"

RSpec.describe StoryIdea, type: :model do
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
  end
end
