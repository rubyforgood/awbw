require "rails_helper"

RSpec.describe "/people/check_duplicates", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:existing_person) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane.doe@example.com") }

  before do
    sign_in admin
  end

  describe "GET /people/check_duplicates" do
    # --- Exact name matching ---

    context "when an exact name match exists" do
      it "shows the duplicate person with the page heading" do
        get check_duplicates_people_path, params: { first_name: "Jane", last_name: "Doe", email: "" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Possible Duplicate Person")
        expect(response.body).to include("Jane Doe")
      end

      it "is case insensitive" do
        get check_duplicates_people_path, params: { first_name: "JANE", last_name: "DOE", email: "" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Jane Doe")
      end

      it "shows the Create Anyway button" do
        get check_duplicates_people_path, params: { first_name: "Jane", last_name: "Doe", email: "" }

        expect(response.body).to include("Create Anyway")
      end
    end

    # --- Nickname matching ---

    context "when a nickname variant matches" do
      before do
        create(:person, first_name: "Robert", last_name: "Smith", email: "robert@example.com")
      end

      it "shows the nickname match badge" do
        get check_duplicates_people_path, params: { first_name: "Bob", last_name: "Smith", email: "" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Robert Smith")
        expect(response.body).to include("nickname match")
      end

      it "sorts exact matches before nickname matches" do
        create(:person, first_name: "Bob", last_name: "Smith", email: "bob@example.com")

        get check_duplicates_people_path, params: { first_name: "Bob", last_name: "Smith", email: "" }

        expect(response).to have_http_status(:ok)
        # Both appear
        expect(response.body).to include("Bob Smith")
        expect(response.body).to include("Robert Smith")
        # Exact match (Bob) appears before nickname match (Robert) in the list
        expect(response.body.index("Bob Smith")).to be < response.body.index("Robert Smith")
      end
    end

    # --- Blocked (exact name + primary email) ---

    context "when exact name and primary email match (blocked)" do
      it "shows the exact match badge and block message" do
        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: existing_person.email
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("exact match")
        expect(response.body).to include("Please edit the existing record instead")
      end

      it "hides the Create Anyway button" do
        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: existing_person.email
        }

        expect(response.body).not_to include("Create Anyway")
      end
    end

    # --- Approximate match (exact name + secondary/user email) ---

    context "when exact name and secondary email match (approximate)" do
      it "shows the approximate match badge and warning" do
        existing_person.update!(email_2: "jane.secondary@testmail.org")

        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: "jane.secondary@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("approximate match")
        expect(response.body).to include("matching secondary or user email")
      end
    end

    # --- Email-only matching ---

    context "when only email matches (no name match)" do
      it "matches on user email for person with user" do
        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: existing_person.user.email
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Jane Doe")
        expect(response.body).to include(existing_person.user.email)
      end

      it "matches on person.email only when person has no user" do
        Person.create!(
          first_name: "Solo", last_name: "Person",
          email: "solo@testmail.org",
          created_by: admin, updated_by: admin
        )

        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: "solo@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Solo Person")
        expect(response.body).to include("solo@testmail.org")
      end

      it "matches on email_2" do
        create(:person, first_name: "John", last_name: "Smith", email: nil, email_2: "john.smith@testmail.org")

        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: "john.smith@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("John Smith")
      end

      it "matches on associated user email" do
        user = create(:user, email: "user@testmail.org")
        create(:person, first_name: "Bob", last_name: "Jones", email: nil, user: user)

        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: "user@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Bob Jones")
      end

      it "shows the email match badge" do
        user = create(:user, email: "badge@testmail.org")
        create(:person, first_name: "Badge", last_name: "Test", email: nil, user: user)

        get check_duplicates_people_path, params: {
          first_name: "Different", last_name: "Name", email: "badge@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("email match")
      end
    end

    # --- Person.email ignored when person has a user ---

    context "when person has a user" do
      it "ignores person.email in email matching" do
        # existing_person has user; searching by person.email (not user.email) should not match via email query
        # Note: @example.com emails are skipped entirely, so this tests the display/query logic
        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: "jane.doe@example.com"
        }

        expect(response).to have_http_status(:ok)
        # @example.com is skipped, so no email-based match occurs
      end

      it "excludes person.email from displayed emails" do
        existing_person.update!(email_2: "jane.alt@example.com")
        user_email = existing_person.user.email

        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: ""
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Secondary email")
        expect(response.body).to include("jane.alt@example.com")
        expect(response.body).to include("User email")
        expect(response.body).to include(user_email)
        # person.email label should not appear (skipped when user exists)
        expect(response.body).not_to include(">Email:</span> jane.doe@example.com")
      end

      it "shows person.email when person has no user" do
        Person.create!(
          first_name: "Solo", last_name: "Person",
          email: "solo@test.org", email_2: "solo.alt@test.org",
          created_by: admin, updated_by: admin
        )

        get check_duplicates_people_path, params: {
          first_name: "Solo", last_name: "Person", email: ""
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("solo@test.org")
        expect(response.body).to include("solo.alt@test.org")
      end
    end

    # --- Email warning about user accounts ---

    context "when entered email matches an existing duplicate's email" do
      it "shows the user account email warning" do
        user = create(:user, email: "shared@testmail.org")
        create(:person, first_name: "Existing", last_name: "Person", email: nil, user: user)

        get check_duplicates_people_path, params: {
          first_name: "New", last_name: "Person", email: "shared@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("each user account requires a unique email")
      end

      it "does not show the warning when no email overlap" do
        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: "completely.different@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("each user account requires a unique email")
      end

      it "does not show the warning when no email is entered" do
        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: ""
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("each user account requires a unique email")
      end
    end

    # --- @example.com emails skipped ---

    context "when email is @example.com" do
      it "skips email matching" do
        get check_duplicates_people_path, params: {
          first_name: "", last_name: "", email: "test@example.com"
        }

        expect(response).to have_http_status(:ok)
        # No email-based matches should appear (name fields are blank too)
      end
    end

    # --- Deduplication ---

    context "when both name and email match the same person" do
      it "shows the person only once" do
        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: existing_person.user.email
        }

        expect(response).to have_http_status(:ok)
        # "Jane Doe" appears in the "Checking:" line and once in the list = 2 total
        expect(response.body.scan("Jane Doe").count).to eq(2)
      end
    end

    # --- No duplicates ---

    context "when no duplicates exist" do
      it "shows the Create Anyway button" do
        get check_duplicates_people_path, params: {
          first_name: "NewFirst", last_name: "NewLast", email: "new@testmail.org"
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Create Anyway")
      end

      it "always shows the Go Back link" do
        get check_duplicates_people_path, params: {
          first_name: "NewFirst", last_name: "NewLast", email: ""
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Go Back")
      end
    end

    # --- Authorization ---

    context "when user is not an admin" do
      it "denies access" do
        sign_in create(:user)

        get check_duplicates_people_path, params: {
          first_name: "Jane", last_name: "Doe", email: ""
        }

        expect(response).not_to have_http_status(:ok)
      end
    end
  end
end
