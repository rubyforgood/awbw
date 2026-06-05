require 'rails_helper'

RSpec.describe Tutorial, type: :model do
  describe '.search_by_params' do
    let!(:published_tutorial) { create(:tutorial, :published, title: 'Getting Started Guide', rhino_body: 'Welcome to AWBW') }
    let!(:draft_tutorial) { create(:tutorial, title: 'Advanced Workshop Tips', rhino_body: 'For experienced facilitators') }

    it 'returns all when no params' do
      results = Tutorial.search_by_params({})
      expect(results).to include(published_tutorial, draft_tutorial)
    end

    it 'filters by search (title or body)' do
      results = Tutorial.search_by_params(search: 'Getting Started')
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end

    it 'filters by search matching body content' do
      results = Tutorial.search_by_params(search: 'facilitators')
      expect(results).to include(draft_tutorial)
      expect(results).not_to include(published_tutorial)
    end

    it 'filters by title only' do
      results = Tutorial.search_by_params(title: 'Advanced')
      expect(results).to include(draft_tutorial)
      expect(results).not_to include(published_tutorial)
    end

    it 'filters by published param' do
      results = Tutorial.search_by_params(published: 'true')
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end

    it 'chains search and published filters' do
      results = Tutorial.search_by_params(search: 'Guide', published: 'true')
      expect(results).to include(published_tutorial)
      expect(results).not_to include(draft_tutorial)
    end
  end
end
