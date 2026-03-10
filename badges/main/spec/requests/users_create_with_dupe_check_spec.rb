require "rails_helper"

RSpec.describe "POST /users with duplicate check", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: nil) }

  before { sign_in admin }

  context "when a person with matching email exists (not blocked)" do
    before do
      Person.create!(
        first_name: "Solo", last_name: "Person",
        email: "solo@testmail.org",
        created_by: admin, updated_by: admin
      )
    end

    it "renders the new form with duplicate warning instead of redirecting" do
      post users_path, params: {
        person_id: person.id,
        user: { email: "solo@testmail.org" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Possible duplicate user")
      expect(response.body).to include("solo@testmail.org")
    end

    it "preserves person_id in the Create anyway form" do
      post users_path, params: {
        person_id: person.id,
        user: { email: "solo@testmail.org" }
      }

      expect(response.body).to include(person.id.to_s)
    end

    it "creates the user with all params when Create anyway is submitted" do
      expect {
        post users_path, params: {
          skip_duplicate_check: "1",
          person_id: person.id,
          user: { email: "solo@testmail.org" }
        }
      }.to change(User, :count).by(1)

      created = User.last
      expect(created.email).to eq("solo@testmail.org")
      expect(created.person).to eq(person)
    end
  end

  context "when a user with matching email exists (blocked)" do
    let!(:existing_user) { create(:user, email: "taken@testmail.org") }

    it "renders the new form with blocked message" do
      post users_path, params: {
        user: { email: "taken@testmail.org" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Possible duplicate user")
      expect(response.body).not_to include("Create anyway")
    end
  end

  context "when no duplicates are found" do
    it "creates the user normally" do
      expect {
        post users_path, params: {
          person_id: person.id,
          user: { email: "brand.new@testmail.org" }
        }
      }.to change(User, :count).by(1)
    end
  end
end
