require "rails_helper"

RSpec.describe "People search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results" } }

  before { sign_in admin }

  describe "GET /people (turbo frame)" do
    let!(:person_alice) { create(:person, first_name: "Alice", last_name: "Wonderland") }
    let!(:person_bob)   { create(:person, first_name: "Bob", last_name: "Builder") }

    it "returns search results successfully" do
      get people_path, headers: turbo_headers
      expect(response).to have_http_status(:ok)
    end

    it "returns all people when no filters are applied" do
      get people_path, headers: turbo_headers
      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
    end

    it "filters by contact_info" do
      get people_path, params: { contact_info: "Alice" }, headers: turbo_headers
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by organization name" do
      org = create(:organization, name: "Unique Org")
      create(:affiliation, person: person_alice, organization: org)

      get people_path, params: { organization_name: "Unique Org" }, headers: turbo_headers
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end
  end
end
