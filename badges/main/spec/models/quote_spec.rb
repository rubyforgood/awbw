require 'rails_helper'

RSpec.describe Quote do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    # it { should have_many(:quotable_item_quotes) } # Model missing has_many
    # Through associations can sometimes be tricky, test if needed
    # it { should have_many(:reports).through(:quotable_item_quotes).source(:quotable).source_type('Report') }
    # it { should have_many(:workshops).through(:quotable_item_quotes).source(:quotable).source_type('Workshop') }
  end

  describe 'validations' do
    subject { build(:quote) }
    # it { should validate_presence_of(:quote) } # Model missing validation
    # Add other validations if needed (e.g., age, gender format)
  end

  describe 'scopes' do
    let!(:published_quote) { create(:quote, :published) }
    let!(:unpublished_quote) { create(:quote, :unpublished) }

    it '.active returns only active quotes' do
      expect(Quote.published).to include(published_quote)
      expect(Quote.published).not_to include(unpublished_quote)
    end
  end

  describe '#speaker' do
    it 'returns speaker_name if present' do
      quote = build(:quote, speaker_name: "John Doe")
      expect(quote.speaker).to eq("John Doe")
    end

    it 'returns "Anonymous" if speaker_name is nil' do
      quote = build(:quote, speaker_name: nil)
      expect(quote.speaker).to eq("Anonymous")
    end

    it 'returns "Anonymous" if speaker_name is empty' do
      quote = build(:quote, speaker_name: "")
      expect(quote.speaker).to eq("Anonymous")
    end
  end

  it 'is valid with valid attributes' do
    expect(build(:quote)).to be_valid
  end

  describe 'capturing the original submission' do
    it 'copies the body into original_body the first time it is saved' do
      quote = create(:quote, body: 'As received')
      expect(quote.original_body).to eq('As received')
    end

    it 'keeps the original untouched when the published body is later edited' do
      quote = create(:quote, body: 'As received')
      quote.update!(body: 'Cleaned up for publication')
      expect(quote.original_body).to eq('As received')
      expect(quote.body).to eq('Cleaned up for publication')
    end

    it 'does not overwrite an explicitly provided original' do
      quote = create(:quote, body: 'Published', original_body: 'Raw original')
      expect(quote.original_body).to eq('Raw original')
    end
  end

  describe '.search_by_params' do
    let!(:published_quote) { create(:quote, :published, body: 'Art heals the soul', speaker_name: 'Jane') }
    let!(:another_published) { create(:quote, :published, body: 'Creativity is freedom', speaker_name: 'Bob') }
    let!(:draft_quote) { create(:quote, body: 'Unpublished thought', speaker_name: 'Carol') }

    it 'returns all when no params' do
      results = Quote.search_by_params({})
      expect(results).to include(published_quote, another_published, draft_quote)
    end

    it 'filters by query' do
      results = Quote.search_by_params(query: 'heals')
      expect(results).to include(published_quote)
      expect(results).not_to include(another_published, draft_quote)
    end

    it 'filters by published' do
      results = Quote.search_by_params(published: 'true')
      expect(results).to include(published_quote, another_published)
      expect(results).not_to include(draft_quote)
    end

    it 'chains query and published filters' do
      results = Quote.search_by_params(query: 'freedom', published: 'true')
      expect(results).to include(another_published)
      expect(results).not_to include(published_quote, draft_quote)
    end

    it 'matches on the original submission as well as the published body' do
      quote = create(:quote, body: 'Cleaned up', original_body: 'raw submitted words')
      results = Quote.search_by_params(query: 'submitted')
      expect(results).to include(quote)
      expect(results).not_to include(published_quote, another_published)
    end

    it 'matches on the legacy speaker name' do
      results = Quote.search_by_params(query: 'Carol')
      expect(results).to include(draft_quote)
      expect(results).not_to include(published_quote, another_published)
    end

    it 'matches on the linked author person name' do
      author = create(:person, first_name: 'Zadie', last_name: 'Okonkwo')
      quote = create(:quote, body: 'Words', speaker_name: nil, author: author)
      results = Quote.search_by_params(query: 'Okonkwo')
      expect(results).to include(quote)
      expect(results).not_to include(published_quote, another_published, draft_quote)
    end

    it 'filters by author' do
      author = create(:person)
      quote = create(:quote, body: 'By a known person', author: author)
      results = Quote.search_by_params(author_id: author.id)
      expect(results).to include(quote)
      expect(results).not_to include(published_quote, another_published, draft_quote)
    end

    it 'filters by standout' do
      standout = create(:quote, :standout, body: 'A gem')
      results = Quote.search_by_params(standout: 'true')
      expect(results).to include(standout)
      expect(results).not_to include(published_quote, another_published, draft_quote)
    end

    it 'filters by source type' do
      from_log = create(:quote, body: 'From a log')
      create(:quotable_item_quote, quote: from_log, quotable: create(:workshop_log))
      results = Quote.search_by_params(source_type: 'WorkshopLog')
      expect(results).to include(from_log)
      expect(results).not_to include(published_quote, another_published, draft_quote)
    end
  end

  describe '.source_type_options' do
    it 'builds humanized [ label, type ] pairs from the sources in the data' do
      create(:quotable_item_quote, quote: create(:quote), quotable: create(:workshop_log))
      expect(Quote.source_type_options).to include([ 'Workshop log', 'WorkshopLog' ])
    end
  end

  describe '#speaker' do
    it 'prefers the linked author name over the legacy speaker name' do
      author = create(:person, first_name: 'Ada', last_name: 'Lovelace')
      quote = build(:quote, author: author, speaker_name: 'Legacy Name')
      expect(quote.speaker).to eq(author.name)
    end
  end
end
