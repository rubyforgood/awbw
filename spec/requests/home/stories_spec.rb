require "rails_helper"

RSpec.describe "/home/stories", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /home/stories" do
    it "lists featured stories in their curated position order" do
      first = create(:story, :featured, :published, title: "Alpha story")
      second = create(:story, :featured, :published, title: "Bravo story")
      # Curate Bravo ahead of Alpha despite alphabetical order.
      second.update!(position: 1)

      get home_stories_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(second.title)).to be < response.body.index(first.title)
    end
  end
end
