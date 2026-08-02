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

    it "returns an empty array for a blank query" do
      get "/search/person_or_organization", params: { q: "" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  # The `order` param controls which kind leads the combined results.
  describe "result ordering" do
    let!(:person) { create(:person, first_name: "Searchable", last_name: "Payer") }
    let!(:organization) { create(:organization, name: "Searchable Payer Org") }

    def result_kinds(params)
      get "/search/person_or_organization", params: params
      response.parsed_body.map { |row| row["label"].split(" · ").last }.uniq
    end

    it "lists people first by default" do
      expect(result_kinds(q: "Searchable")).to eq([ "Person", "Organization" ])
    end

    it "lists organizations first when order=organization" do
      expect(result_kinds(q: "Searchable", order: "organization")).to eq([ "Organization", "Person" ])
    end
  end
end
