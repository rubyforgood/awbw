require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders section titles as exactly two words" do
      get root_path

      expect(response).to have_http_status(:ok)

      section_titles = response.body
        .scan(%r{<h2 class="text-3xl font-semibold text-gray-900">(.*?)</h2>}m)
        .flatten.map(&:strip)
      expect(section_titles).not_to be_empty, "Expected to find section titles in h2 tags"

      section_titles.each do |title|
        words = title.split
        expect(words.length).to eq(2),
          "Expected section title \"#{title}\" to be two words, but it has #{words.length}"
      end
    end
  end

  describe "GET / (signed in)" do
    it "shows the Upcoming Events and Community News sections" do
      user = create(:user)
      create(:person, user: user)
      sign_in user

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Upcoming Events")
      expect(response.body).to include("Community News")
    end
  end

  describe "GET /home/* (turbo frame lazy loading)" do
    %w[workshops resources events community_news stories video_recordings].each do |section|
      it "#{section} returns 200 for visitors" do
        get "/home/#{section}"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
