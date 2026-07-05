require 'rails_helper'

RSpec.describe CommunityNews, type: :model do
  it_behaves_like "author_creditable", factory: :community_news

  describe "#author_person" do
    let(:creator) { create(:user, :with_person) }
    let(:legacy_author_user) { create(:user, :with_person) }
    let(:person) { create(:person) }

    it "returns the explicit person author when present" do
      news = create(:community_news, created_by: creator, author: person)
      expect(news.author_person).to eq(person)
    end

    it "falls back to the legacy display-author user's person" do
      news = create(:community_news, created_by: creator, author: nil, legacy_author_user: legacy_author_user)
      expect(news.author_person).to eq(legacy_author_user.person)
    end

    it "falls back to the creating user's person when nothing else is set" do
      news = create(:community_news, created_by: creator, author: nil, legacy_author_user: nil)
      expect(news.author_person).to eq(creator.person)
    end
  end

  describe '.search' do
    let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }

    let!(:community_news_with_person) do
      create(:community_news,
             title: 'Breaking News',
             author: person,
             rhino_body: '<p>This is important content about technology</p>')
    end

    let!(:community_news_without_person) do
      create(:community_news,
             title: 'Special Report',
             author: nil,
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

    context 'when filtering by year' do
      let!(:news_2025) do
        create(:community_news, title: 'Old News', created_at: Date.new(2025, 6, 15))
      end

      let!(:news_2026) do
        create(:community_news, title: 'New News', created_at: Date.new(2026, 3, 1))
      end

      it 'returns records from the specified year' do
        results = CommunityNews.by_year('2025')
        expect(results).to include(news_2025)
        expect(results).not_to include(news_2026)
      end

      it 'returns records from a different year' do
        results = CommunityNews.by_year('2026')
        expect(results).to include(news_2026)
        expect(results).not_to include(news_2025)
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

  describe '.search_by_params' do
    let(:person) { create(:person, first_name: 'John', last_name: 'Doe') }

    let!(:news_alpha) do
      create(:community_news, :published,
             title: 'Alpha Community Update',
             author: person,
             created_at: Date.new(2025, 6, 15))
    end

    let!(:news_beta) do
      create(:community_news,
             title: 'Beta Draft Article',
             author: person,
             created_at: Date.new(2026, 3, 1))
    end

    it 'returns all when no params' do
      results = CommunityNews.search_by_params({})
      expect(results).to include(news_alpha, news_beta)
    end

    it 'filters by title' do
      results = CommunityNews.search_by_params(title: 'Alpha')
      expect(results).to include(news_alpha)
      expect(results).not_to include(news_beta)
    end

    it 'filters by published param' do
      results = CommunityNews.search_by_params(published: 'true')
      expect(results).to include(news_alpha)
      expect(results).not_to include(news_beta)
    end

    it 'filters by year' do
      results = CommunityNews.search_by_params(year: '2025')
      expect(results).to include(news_alpha)
      expect(results).not_to include(news_beta)
    end

    it 'ignores invalid year format' do
      results = CommunityNews.search_by_params(year: 'abc')
      expect(results).to include(news_alpha, news_beta)
    end

    it 'chains title and year filters' do
      results = CommunityNews.search_by_params(title: 'Alpha', year: '2025')
      expect(results).to include(news_alpha)
      expect(results).not_to include(news_beta)
    end

    it 'filters by organization_id' do
      organization = create(:organization)
      org_news = create(:community_news, author: person, organization: organization)

      results = CommunityNews.search_by_params(organization_id: organization.id)
      expect(results).to include(org_news)
      expect(results).not_to include(news_alpha, news_beta)
    end
  end
end
