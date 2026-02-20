require 'rails_helper'

RSpec.describe CommunityNews, type: :model do
  describe '.search' do
    let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }
    let(:user_with_person) { person.user }
    let(:user_without_person) { create(:user, person: nil) }

    let!(:community_news_with_person) do
      create(:community_news,
             title: 'Breaking News',
             author: user_with_person,
             rhino_body: '<p>This is important content about technology</p>')
    end

    let!(:community_news_without_person) do
      create(:community_news,
             title: 'Special Report',
             author: user_without_person,
             rhino_body: '<p>Burgers and fries are delicious</p>')
    end

    context 'when searching by title' do
      it 'finds records matching the title' do
        results = CommunityNews.search('Breaking')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds records with partial title matches' do
        results = CommunityNews.search('Report')
        expect(results).to include(community_news_without_person)
        expect(results).not_to include(community_news_with_person)
      end
    end

    context 'when searching by person name' do
      it 'finds records by person first name' do
        results = CommunityNews.search('John')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds records by person last name' do
        results = CommunityNews.search('Doe')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds records by partial person name' do
        results = CommunityNews.search('Joh')
        expect(results).to include(community_news_with_person)
      end
    end

    context 'when searching by content body' do
      it 'finds records by content in rhino_body' do
        results = CommunityNews.search('technology')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds records by content in records without person' do
        results = CommunityNews.search('Burgers')
        expect(results).to include(community_news_without_person)
        expect(results).not_to include(community_news_with_person)
      end

      it 'finds records by partial content matches' do
        results = CommunityNews.search('delicious')
        expect(results).to include(community_news_without_person)
      end
    end

    context 'when searching with multiple terms' do
      it 'finds records matching all terms across different fields' do
        results = CommunityNews.search('John Breaking')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds records matching content and person name' do
        results = CommunityNews.search('John technology')
        expect(results).to include(community_news_with_person)
      end
    end

    context 'when search term is not found' do
      it 'returns empty results for non-existent terms' do
        results = CommunityNews.search('NonExistentTerm')
        expect(results).to be_empty
      end
    end

    context 'AND operator behavior for multiple search terms' do
      it 'requires all search terms to match across different fields' do
        results = CommunityNews.search('John Breaking')
        expect(results).to include(community_news_with_person)
        expect(results).not_to include(community_news_without_person)
      end

      it 'finds no results when terms match different records' do
        results = CommunityNews.search('John Report')
        expect(results).to be_empty
      end

      it 'finds no results when content and title are in different records' do
        results = CommunityNews.search('Breaking Burgers')
        expect(results).to be_empty
      end
    end

    context 'LEFT JOIN behavior' do
      it 'includes records without people in search results' do
        results = CommunityNews.search('Special')
        expect(results).to include(community_news_without_person)
      end

      it 'includes records with people in search results' do
        results = CommunityNews.search('Breaking')
        expect(results).to include(community_news_with_person)
      end

      it 'searches across both types of records for common terms' do
        # Create records with common content to test cross-record searching
        community_news_with_person.update!(rhino_body: '<p>This is shared content</p>')
        community_news_without_person.update!(rhino_body: '<p>This is shared content</p>')

        results = CommunityNews.search('shared')
        expect(results.count).to eq(2)
        expect(results).to include(community_news_with_person)
        expect(results).to include(community_news_without_person)
      end
    end
  end
end
