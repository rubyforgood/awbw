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
end
