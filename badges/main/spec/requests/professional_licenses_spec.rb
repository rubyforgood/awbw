require "rails_helper"

RSpec.describe "ProfessionalLicenses", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:license) { create(:professional_license, person: person, kind: "LMFT", number: "555") }

  describe "as an admin" do
    before { sign_in admin }

    it "renders the index shell" do
      get professional_licenses_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Licenses")
    end

    it "lists licenses in the results turbo frame" do
      get professional_licenses_path,
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.full_name)
      expect(response.body).to include("555")
    end

    it "filters by type" do
      other = create(:professional_license, kind: "LCSW", number: "999")

      get professional_licenses_path(kind: "LMFT"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body).to include("555")
      expect(response.body).not_to include("999")
    end

    it "filters by expiry status" do
      license.update!(expires_on: 1.year.ago.to_date)
      current = create(:professional_license, number: "222", expires_on: 1.year.from_now.to_date)

      get professional_licenses_path(expired: "yes"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body).to include("555")
      expect(response.body).not_to include("222")
    end
  end

  it "forbids non-admins" do
    sign_in create(:user)
    get professional_licenses_path
    expect(response).not_to have_http_status(:ok)
  end
end
