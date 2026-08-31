require 'rails_helper'

RSpec.describe CommunityNewsDecorator do
  describe "#detail" do
    it "returns the plain-text body" do
      news = build(:community_news, rhino_body: "<p>Hello <strong>world</strong></p>").decorate
      expect(news.detail).to eq("Hello world")
    end

    it "truncates to the given length" do
      news = build(:community_news, rhino_body: "<p>#{'word ' * 80}</p>").decorate
      expect(news.detail(length: 30).length).to be <= 30
      expect(news.detail(length: 30)).to end_with("...")
    end

    it "returns an empty string when the body is blank" do
      news = build(:community_news, rhino_body: "").decorate
      expect(news.detail).to eq("")
    end
  end
end
