require 'rails_helper'

RSpec.describe Story, type: :model do
  it_behaves_like "author_creditable", factory: :story

  describe '.search_by_params' do
    let!(:published_story) { create(:story, :published, title: 'Healing Through Art') }
    let!(:draft_story) { create(:story, title: 'Unpublished Draft', published: false) }
    let!(:old_story) do
      create(:story, :published, title: 'Last Year Story').tap do |s|
        s.update_columns(created_at: Date.new(2025, 5, 1))
      end
    end

    it 'returns all when no params' do
      results = Story.search_by_params({})
      expect(results).to include(published_story, draft_story, old_story)
    end

    it 'filters by title' do
      results = Story.search_by_params(title: 'Healing')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by published param' do
      results = Story.search_by_params(published: 'true')
      expect(results).to include(published_story, old_story)
      expect(results).not_to include(draft_story)
    end

    it 'filters by year' do
      results = Story.search_by_params(year: '2025')
      expect(results).to include(old_story)
      expect(results).not_to include(published_story)
    end

    it 'chains title and published filters' do
      results = Story.search_by_params(title: 'Healing', published: 'true')
      expect(results).to include(published_story)
      expect(results).not_to include(draft_story, old_story)
    end
  end
end
