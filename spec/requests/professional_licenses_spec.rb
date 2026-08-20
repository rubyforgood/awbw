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

    it "filters by registrant name" do
      holder = create(:person, first_name: "Zephyrina", last_name: "Aldercott")
      create(:professional_license, person: holder, number: "444")

      get professional_licenses_path(person_query: "Zephyrina"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body).to include("444")
      expect(response.body).not_to include("555")
    end

    it "filters by registrant email" do
      holder = create(:person, email: "unique-holder@example.com")
      create(:professional_license, person: holder, number: "333")

      get professional_licenses_path(person_query: "unique-holder@example.com"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body).to include("333")
      expect(response.body).not_to include("555")
    end

    it "filters by expiry status" do
      license.update!(expires_on: 1.year.ago.to_date)
      current = create(:professional_license, number: "222", expires_on: 1.year.from_now.to_date)

      get professional_licenses_path(expired: "yes"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body).to include("555")
      expect(response.body).not_to include("222")
    end

    it "sorts by license number" do
      holder = create(:person)
      create(:professional_license, person: holder, kind: "LMFT", number: "111")
      create(:professional_license, person: holder, kind: "LMFT", number: "999")

      get professional_licenses_path(person_query: holder.full_name, sort: "number", direction: "asc"),
        headers: { "Turbo-Frame" => "professional_licenses_results" }

      expect(response.body.index("111")).to be < response.body.index("999")
    end

    it "renders the new license form" do
      get new_professional_license_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New license")
    end

    it "creates a license for the selected person" do
      expect do
        post professional_licenses_path, params: {
          professional_license: { person_id: person.id, number: "777", kind: "LCSW", issuing_state: "CA" }
        }
      end.to change(ProfessionalLicense, :count).by(1)

      expect(response).to redirect_to(professional_licenses_path)
      created = ProfessionalLicense.order(:created_at).last
      expect(created.person).to eq(person)
      expect(created.number).to eq("777")
      expect(created.created_by).to eq(admin)
    end

    it "re-renders new when the person is missing" do
      expect do
        post professional_licenses_path, params: {
          professional_license: { number: "888", kind: "LMFT" }
        }
      end.not_to change(ProfessionalLicense, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "renders the edit license form" do
      get edit_professional_license_path(license)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit license")
      expect(response.body).to include(person.full_name)
    end

    it "updates the license fields" do
      patch professional_license_path(license), params: {
        professional_license: { number: "556", kind: "LCSW", issuing_state: "NY" }
      }

      expect(response).to redirect_to(professional_licenses_path)
      license.reload
      expect(license.number).to eq("556")
      expect(license.kind).to eq("LCSW")
      expect(license.issuing_state).to eq("NY")
      expect(license.person).to eq(person)
    end

    it "does not let the registrant be reassigned on update" do
      other = create(:person)

      patch professional_license_path(license), params: {
        professional_license: { person_id: other.id, number: "556" }
      }

      expect(license.reload.person).to eq(person)
    end
  end

  it "forbids non-admins" do
    sign_in create(:user)
    get professional_licenses_path
    expect(response).not_to have_http_status(:ok)
  end

  it "forbids non-admins from the new license form" do
    sign_in create(:user)
    get new_professional_license_path
    expect(response).not_to have_http_status(:ok)
  end

  it "forbids non-admins from creating a license for another person" do
    sign_in create(:user)
    expect do
      post professional_licenses_path, params: {
        professional_license: { person_id: person.id, number: "999", kind: "LMFT" }
      }
    end.not_to change(ProfessionalLicense, :count)
    expect(response).not_to have_http_status(:ok)
  end

  it "forbids non-admins from editing another person's license" do
    sign_in create(:user)
    get edit_professional_license_path(license)
    expect(response).not_to have_http_status(:ok)

    patch professional_license_path(license), params: { professional_license: { number: "000" } }
    expect(license.reload.number).to eq("555")
  end
end
