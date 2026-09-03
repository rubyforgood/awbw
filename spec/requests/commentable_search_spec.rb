require "rails_helper"

RSpec.describe "Commentable search (global comments index composer)", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /search/commentable" do
    it "finds a matching person and resolves back to the record via its sgid" do
      person = create(:person, first_name: "Searchable", last_name: "Commentable")

      get "/search/commentable", params: { q: "Searchable Commentable" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      resolved = json.map { |row| GlobalID::Locator.locate_signed(row["id"]) }
      expect(resolved).to include(person)
    end

    it "finds a matching affiliation, which has no nested comments route" do
      affiliation = create(:affiliation, person: create(:person, last_name: "Affiliatery"))

      get "/search/commentable", params: { q: "Affiliatery" }

      resolved = response.parsed_body.map { |row| GlobalID::Locator.locate_signed(row["id"]) }
      expect(resolved).to include(affiliation)
    end

    it "finds a matching story by title" do
      story = create(:story, title: "A Very Searchable Story Title")

      get "/search/commentable", params: { q: "Very Searchable Story" }

      resolved = response.parsed_body.map { |row| GlobalID::Locator.locate_signed(row["id"]) }
      expect(resolved).to include(story)
    end

    it "returns an empty array for a blank query" do
      get "/search/commentable", params: { q: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "forbids non-admins" do
      sign_in create(:user)
      get "/search/commentable", params: { q: "anything" }
      expect(response).to redirect_to(root_path)
    end
  end
end
