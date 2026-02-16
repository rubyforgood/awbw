require "rails_helper"

RSpec.describe "/users/check_duplicates", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe "GET /users/check_duplicates" do
    # --- Existing user with same email (blocked) ---

    context "when a user with that email already exists" do
      let!(:existing_user) { create(:user, email: "jane@testmail.org") }

      it "shows the existing user badge and block message" do
        get check_duplicates_users_path, params: { email: "jane@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("existing user")
        expect(response.body).to include("with this email already exists")
        expect(response.body).to include("Edit the existing user or change this user")
      end

      it "hides the Create Anyway button" do
        get check_duplicates_users_path, params: { email: "jane@testmail.org" }

        expect(response.body).not_to include("Create Anyway")
      end

      it "is case insensitive" do
        get check_duplicates_users_path, params: { email: "JANE@TESTMAIL.ORG" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("existing user")
      end

      it "links to the existing user" do
        get check_duplicates_users_path, params: { email: "jane@testmail.org" }

        expect(response.body).to include(user_path(existing_user))
      end
    end

    # --- Person with matching email but no user (not blocked) ---

    context "when a person without a user has a matching email" do
      before do
        Person.create!(
          first_name: "Solo", last_name: "Person",
          email: "solo@testmail.org",
          created_by: admin, updated_by: admin
        )
      end

      it "shows the person badge" do
        get check_duplicates_users_path, params: { email: "solo@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("no user")
        expect(response.body).to include("Solo Person")
      end

      it "shows the Create Anyway button" do
        get check_duplicates_users_path, params: { email: "solo@testmail.org" }

        expect(response.body).to include("Create Anyway")
      end

      it "does not show the block message" do
        get check_duplicates_users_path, params: { email: "solo@testmail.org" }

        expect(response.body).not_to include("with this email already exists")
      end
    end

    context "when a person without a user has a matching email_2" do
      before do
        Person.create!(
          first_name: "Alt", last_name: "Email",
          email: nil, email_2: "alt@testmail.org",
          created_by: admin, updated_by: admin
        )
      end

      it "shows the person match" do
        get check_duplicates_users_path, params: { email: "alt@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alt Email")
        expect(response.body).to include("no user")
      end
    end

    # --- Person with a user is not matched via person.email ---

    context "when a person with a user has a matching person.email" do
      before do
        create(:person, first_name: "Linked", last_name: "Person", email: "linked@testmail.org")
      end

      it "does not match on person.email when person has a user" do
        get check_duplicates_users_path, params: { email: "linked@testmail.org" }

        expect(response).to have_http_status(:ok)
        # Should not appear as a person match (person has a user, so person.email is skipped)
        expect(response.body).not_to include("no user")
      end
    end

    # --- Both user and person matches ---

    context "when both a user and an unlinked person match" do
      let!(:existing_user) { create(:user, email: "shared@testmail.org") }

      before do
        Person.create!(
          first_name: "Unlinked", last_name: "Person",
          email: "shared@testmail.org",
          created_by: admin, updated_by: admin
        )
      end

      it "shows both matches" do
        get check_duplicates_users_path, params: { email: "shared@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("existing user")
        expect(response.body).to include("no user")
      end

      it "is blocked because a user exists" do
        get check_duplicates_users_path, params: { email: "shared@testmail.org" }

        expect(response.body).not_to include("Create Anyway")
      end
    end

    # --- person_id passthrough ---

    context "when person_id is provided" do
      it "includes person_id in the Create Anyway form" do
        person = Person.create!(
          first_name: "Solo", last_name: "Person",
          email: "solo2@testmail.org",
          created_by: admin, updated_by: admin
        )

        get check_duplicates_users_path, params: { email: "solo2@testmail.org", person_id: person.id }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("person_id")
        expect(response.body).to include(person.id.to_s)
      end
    end

    # --- Page heading and layout ---

    context "page structure" do
      let!(:existing_user) { create(:user, email: "heading@testmail.org") }

      it "shows the page heading" do
        get check_duplicates_users_path, params: { email: "heading@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Possible Duplicate User")
      end

      it "displays the checked email" do
        get check_duplicates_users_path, params: { email: "heading@testmail.org" }

        expect(response.body).to include("heading@testmail.org")
      end

      it "always shows the Go Back link" do
        get check_duplicates_users_path, params: { email: "heading@testmail.org" }

        expect(response.body).to include("Go Back")
      end
    end

    # --- No duplicates ---

    context "when no duplicates exist" do
      it "shows the Create Anyway button" do
        get check_duplicates_users_path, params: { email: "brand.new@testmail.org" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Create Anyway")
      end

      it "does not show any duplicate badges" do
        get check_duplicates_users_path, params: { email: "brand.new@testmail.org" }

        expect(response.body).not_to include("existing user")
        expect(response.body).not_to include("no user")
      end
    end

    # --- Authorization ---

    context "when user is not an admin" do
      it "denies access" do
        sign_in create(:user)

        get check_duplicates_users_path, params: { email: "test@testmail.org" }

        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
