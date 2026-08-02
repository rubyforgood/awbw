require "rails_helper"

RSpec.describe "Payer search (combined people + organizations)", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /search/person_or_organization" do
    let!(:person) { create(:person, first_name: "Searchable", last_name: "Payer") }
    let!(:organization) { create(:organization, name: "Searchable Payer Org") }

    it "returns both people and organizations with sgid values" do
      get "/search/person_or_organization", params: { q: "Searchable" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      labels = json.map { |row| row["label"] }
      expect(labels).to include(a_string_including("Searchable Payer").and(a_string_including("Person")))
      expect(labels).to include(a_string_including("Searchable Payer Org").and(a_string_including("Organization")))

      # SGIDs carry an expiry, so they vary per call — resolve them instead of
      # comparing strings.
      resolved = json.map { |row| GlobalID::Locator.locate_signed(row["id"]) }
      expect(resolved).to include(person)
      expect(resolved).to include(organization)
    end

    it "lists organizations before people" do
      get "/search/person_or_organization", params: { q: "Searchable" }

      kinds = response.parsed_body.map { |row| row["label"].split(" · ").last }
      expect(kinds.index("Organization")).to be < kinds.index("Person")
    end

    it "returns an empty array for a blank query" do
      get "/search/person_or_organization", params: { q: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end
end
