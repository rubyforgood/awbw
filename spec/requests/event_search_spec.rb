require "rails_helper"

RSpec.describe "Event search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:summit) { create(:event, title: "Annual Summit") }
  let!(:retreat) { create(:event, title: "Quiet Retreat") }

  describe "GET /search/event" do
    context "as an admin" do
      before { sign_in admin }

      it "returns matching events as id/label JSON" do
        get "/search/event", params: { q: "Summit" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.map { |r| r["id"] }).to contain_exactly(summit.id)
        expect(json.first["label"]).to include("Annual Summit")
      end

      it "returns an empty array for a blank query" do
        get "/search/event", params: { q: "" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq([])
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "is not authorized" do
        get "/search/event", params: { q: "Summit" }

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "GET /search/event_registration" do
    let!(:registrant) { create(:person, first_name: "Fay", last_name: "Finder") }
    let!(:active_registration) { create(:event_registration, registrant: registrant, status: "registered") }
    let!(:transferred_out_registration) { create(:event_registration, registrant: registrant, status: "transferred_out") }
    let!(:incoming_registration) do
      create(:event_registration, registrant: registrant, status: "registered",
             transferred_from_registration: create(:event_registration, status: "transferred_out"))
    end

    context "as an admin" do
      before { sign_in admin }

      it "returns every event and status" do
        get "/search/event_registration", params: { q: "Finder" }

        expect(response).to have_http_status(:ok)
        ids = response.parsed_body.map { |row| row["id"] }
        expect(ids).to include(active_registration.id, transferred_out_registration.id, incoming_registration.id)
      end

      it "omits excluded ids" do
        get "/search/event_registration",
            params: { q: "Finder", exclude: active_registration.id.to_s }

        expect(response.parsed_body.map { |row| row["id"] }).not_to include(active_registration.id)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "is not authorized" do
        get "/search/event_registration", params: { q: "Finder" }

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
