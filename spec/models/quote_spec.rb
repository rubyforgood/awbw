# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Quote) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "scopes" do
    let!(:active_quote) { create(:quote, inactive: false) }
    let!(:inactive_quote) { create(:quote, inactive: true) }

    it ".active returns only active quotes" do
      expect(described_class.active).to(include(active_quote))
      expect(described_class.active).not_to(include(inactive_quote))
    end
  end

  describe "#speaker" do
    it "returns speaker_name if present" do
      quote = build(:quote, speaker_name: "John Doe")
      expect(quote.speaker).to(eq("John Doe"))
    end

    it 'returns "Participant" if speaker_name is nil' do
      quote = build(:quote, speaker_name: nil)
      expect(quote.speaker).to(eq("Participant"))
    end

    it 'returns "Participant" if speaker_name is empty' do
      quote = build(:quote, speaker_name: "")
      expect(quote.speaker).to(eq("Participant"))
    end
  end

  it "is valid with valid attributes" do
    expect(build(:quote)).to(be_valid)
  end
end
