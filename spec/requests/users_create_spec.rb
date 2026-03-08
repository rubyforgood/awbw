require "rails_helper"

RSpec.describe "POST /users", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "duplicate check on create" do
    let!(:existing_person) do
      Person.create!(
        first_name: "Solo", last_name: "Person",
        email: "solo@testmail.org",
        created_by: admin, updated_by: admin
      )
    end

    it "renders check_duplicates when a duplicate is found" do
      post users_path, params: {
        user: {
          email: "solo@testmail.org",
          first_name: "New",
          last_name: "User"
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Possible duplicate user")
      expect(response.body).to include("solo@testmail.org")
    end

    it "does not create the user when duplicates are found" do
      expect {
        post users_path, params: {
          user: {
            email: "solo@testmail.org",
            first_name: "New",
            last_name: "User"
          }
        }
      }.not_to change(User, :count)
    end

    it "includes form params as hidden fields for Create anyway" do
      post users_path, params: {
        user: {
          email: "solo@testmail.org",
          first_name: "New",
          last_name: "User"
        }
      }

      expect(response.body).to include("solo@testmail.org")
      expect(response.body).to include("skip_duplicate_check")
    end

    it "creates the user when skip_duplicate_check is set" do
      expect {
        post users_path, params: {
          skip_duplicate_check: "1",
          user: {
            email: "solo@testmail.org",
            first_name: "New",
            last_name: "User"
          }
        }
      }.to change(User, :count).by(1)
    end
  end
end
