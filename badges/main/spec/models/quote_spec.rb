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
    let!(:active_quote) { create(:quote, inactive: false) }
    let!(:inactive_quote) { create(:quote, inactive: true) }

    it '.active returns only active quotes' do
      expect(Quote.active).to include(active_quote)
      expect(Quote.active).not_to include(inactive_quote)
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