require "rails_helper"

RSpec.describe QuoteDecorator do
  describe "#attribution" do
    it "credits a linked author by their profile-preferred name" do
      author = create(:person, first_name: "Jane", last_name: "Doe",
                               display_name_preference: "first_name_last_initial")
      quote = create(:quote, author: author, speaker_name: nil, age: nil, gender: nil).decorate

      expect(quote.attribution).to eq("Jane D.")
    end

    it "falls back to the free-text speaker_name when there is no linked author" do
      quote = create(:quote, author: nil, speaker_name: "Sam Rivera", age: nil, gender: nil).decorate

      expect(quote.attribution).to eq("Sam Rivera")
    end

    it "reads as Participant when the linked author opted out of being credited" do
      author = create(:person, :anonymous_contributions, first_name: "Jane", last_name: "Doe")
      quote = create(:quote, author: author, speaker_name: nil, age: nil, gender: nil).decorate

      expect(quote.attribution).to eq("Participant")
    end

    it "reads as Participant when there is no author and no speaker name" do
      quote = create(:quote, author: nil, speaker_name: nil, age: nil, gender: nil).decorate

      expect(quote.attribution).to eq("Participant")
    end

    it "appends age and gender details when present" do
      quote = create(:quote, author: nil, speaker_name: "Sam Rivera", age: "34", gender: "F").decorate

      expect(quote.attribution).to eq("Sam Rivera (34 yrs, F)")
    end
  end
end
