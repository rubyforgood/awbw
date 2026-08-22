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

    it 'returns "Participant" if speaker_name is nil' do
      quote = build(:quote, speaker_name: nil)
      expect(quote.speaker).to eq("Participant")
    end

    it 'returns "Participant" if speaker_name is empty' do
      quote = build(:quote, speaker_name: "")
      expect(quote.speaker).to eq("Participant")
    end
  end

  it 'is valid with valid attributes' do
    expect(build(:quote)).to be_valid
  end

  describe 'capturing the original submission' do
    it 'copies the body into original_quote the first time it is saved' do
      quote = create(:quote, quote: 'As received')
      expect(quote.original_quote).to eq('As received')
    end

    it 'keeps the original untouched when the published body is later edited' do
      quote = create(:quote, quote: 'As received')
      quote.update!(quote: 'Cleaned up for publication')
      expect(quote.original_quote).to eq('As received')
      expect(quote.quote).to eq('Cleaned up for publication')
    end

    it 'does not overwrite an explicitly provided original' do
      quote = create(:quote, quote: 'Published', original_quote: 'Raw original')
      expect(quote.original_quote).to eq('Raw original')
    end
  end

  describe '.search_by_params' do
    let!(:published_quote) { create(:quote, :published, quote: 'Art heals the soul', speaker_name: 'Jane') }
    let!(:another_published) { create(:quote, :published, quote: 'Creativity is freedom', speaker_name: 'Bob') }
    let!(:draft_quote) { create(:quote, quote: 'Unpublished thought', speaker_name: 'Carol') }

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
      quote = create(:quote, quote: 'Cleaned up', original_quote: 'raw submitted words')
      results = Quote.search_by_params(query: 'submitted')
      expect(results).to include(quote)
      expect(results).not_to include(published_quote, another_published)
    end

    it 'filters by standout' do
      standout = create(:quote, :standout, quote: 'A gem')
      results = Quote.search_by_params(standout: 'true')
      expect(results).to include(standout)
      expect(results).not_to include(published_quote, another_published, draft_quote)
    end
  end
end
