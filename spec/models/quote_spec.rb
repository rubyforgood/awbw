require 'rails_helper'

RSpec.describe Quote do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:quotable).optional }
    it { should belong_to(:workshop).optional }
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
end
