require "rails_helper"

RSpec.describe "/home/stories", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /home/stories" do
    it "credits both authors on the card, with credentials" do
      author = create(:person, first_name: "Mae", last_name: "Beale", display_name_preference: "full_name")
      create(:professional_license, person: author, kind: "LMFT")
      create(:professional_license, person: author, kind: "MSW")
      co_author = create(:person, first_name: "Cathy", last_name: "Smith",
                                  display_name_preference: "first_name_last_initial")
      create(:story, :published, :featured, title: "A Shared Story", author: author, co_author: co_author,
                                            author_credit_preference: "full_name",
                                            co_author_credit_preference: "first_name_last_initial")

      get home_stories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("A Shared Story")
      expect(response.body).to include("Mae Beale, LMFT, MSW and Cathy S.")
    end

    it "never features a funder-only story on the home feed" do
      create(:story, :published, :featured, :funder_only, title: "Funder Feed Story")

      get home_stories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Funder Feed Story")
    end

    it "falls back to the generic label when the author opts out" do
      author = create(:person, anonymous_contributions: true)
      create(:story, :published, :featured, title: "An Anonymous Story", author: author)

      get home_stories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("AWBW Facilitator")
    end

    it "lists featured stories newest first" do
      create(:story, :published, :featured, title: "Older featured story", created_at: 10.days.ago)
      create(:story, :published, :featured, title: "Newer featured story", created_at: 1.day.ago)

      get home_stories_path

      expect(response.body.index("Newer featured story")).to be < response.body.index("Older featured story")
    end
  end
end
