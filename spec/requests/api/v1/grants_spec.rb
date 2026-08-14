require "rails_helper"

RSpec.describe "Api::V1::Grants", type: :request do
  let(:admin) { create(:user, :admin) }

  let(:funder) { create(:organization, name: "Acme Foundation") }

  let!(:grant) do
    create(:grant,
           name: "Spring 2026 Fund",
           amount_cents: 5_000_000,
           funder: funder,
           funds_received_on: Date.new(2026, 1, 15),
           funds_allocation_deadline: Date.new(2026, 12, 31),
           description: "Supports survivor art-therapy scholarships.",
           eligibility_criteria: "Facilitator-nominated\nUnderserved region",
           tasks: "Submit mid-year report\nAcknowledge funder")
  end

  def json
    JSON.parse(response.body)
  end

  describe "authorization" do
    it "requires authentication" do
      get "/api/v1/grants"

      expect(response).not_to have_http_status(:ok)
    end

    it "forbids non-admins with a JSON error" do
      sign_in create(:user)
      get "/api/v1/grants"

      expect(response).to have_http_status(:forbidden)
      expect(json["error"]).to eq("Forbidden")
    end
  end

  describe "as an admin" do
    before { sign_in admin }

    describe "GET /api/v1/grants" do
      it "returns grants with funder, funds, and tags" do
        sector   = create(:sector, name: "Domestic violence")
        age_type = create(:category_type, name: "AgeRange")
        category = create(:category, name: "6-12", category_type: age_type)
        grant.sectors << sector
        grant.categories << category
        create(:scholarship, grant: grant, amount_cents: 2_000_000)

        get "/api/v1/grants"

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/json")

        payload = json["grants"].find { |g| g["name"] == "Spring 2026 Fund" }
        expect(payload["funder"]).to eq("name" => "Acme Foundation", "type" => "Organization")
        expect(payload["funds"]).to include(
          "amount_cents" => 5_000_000,
          "amount" => "$50,000",
          "allocated_cents" => 2_000_000,
          "remaining_cents" => 3_000_000,
          "fully_issued" => false
        )
        expect(payload["eligibility_criteria"]).to eq([ "Facilitator-nominated", "Underserved region" ])
        expect(payload["tags"]["categories"]).to eq("Age range" => [ "6-12" ])
        expect(payload["tags"]["sectors"]).to eq([ "Domestic violence" ])
        expect(payload["scholarships_count"]).to eq(1)
      end

      it "includes pagination metadata" do
        get "/api/v1/grants"

        expect(json["meta"]).to include(
          "current_page" => 1,
          "per_page" => Api::V1::GrantsController::DEFAULT_PER_PAGE,
          "total_entries" => 1
        )
      end
    end

    describe "GET /api/v1/grants/:id" do
      it "returns a single grant" do
        get "/api/v1/grants/#{grant.id}"

        expect(response).to have_http_status(:ok)
        expect(json["grant"]).to include("name" => "Spring 2026 Fund")
      end

      it "404s for an unknown id" do
        get "/api/v1/grants/0"

        expect(response).to have_http_status(:not_found)
        expect(json["error"]).to eq("Not found")
      end
    end
  end
end
