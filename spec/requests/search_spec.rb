require "rails_helper"

RSpec.describe "Search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  let!(:alice) { create(:person, first_name: "Alice", last_name: "Smith", email: "alice@example.com") }
  let!(:bob) { create(:person, first_name: "Bob", last_name: "Smith", email: "bob@example.com") }
  let!(:carol) { create(:person, first_name: "Carol", last_name: "Jones", email: "carol@test.org") }

  describe "GET /search/person" do
    context "as a guest" do
      it "redirects" do
        get "/search/person", params: { q: "Alice" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "as a regular user" do
      before { sign_in user }

      it "returns forbidden" do
        get "/search/person", params: { q: "Alice" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "returns matching results as JSON" do
        get "/search/person", params: { q: "Alice" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["label"]).to include("Alice")
      end

      it "searches by last name" do
        get "/search/person", params: { q: "Smith" }
        json = JSON.parse(response.body)
        labels = json.map { |r| r["label"] }
        expect(labels).to include(a_string_including("Alice"))
        expect(labels).to include(a_string_including("Bob"))
        expect(labels).not_to include(a_string_including("Carol"))
      end

      it "searches by person email" do
        get "/search/person", params: { q: "carol@test" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["label"]).to include("Carol")
      end

      it "searches by email_2" do
        person = create(:person, first_name: "Dana", last_name: "White", email: nil, email_2: "dana@secondary.org")
        get "/search/person", params: { q: "dana@secondary" }
        json = JSON.parse(response.body)
        ids = json.map { |r| r["id"] }
        expect(ids).to include(person.id)
      end

      it "searches by user email" do
        get "/search/person", params: { q: admin.email }
        json = JSON.parse(response.body)
        ids = json.map { |r| r["id"] }
        expect(ids).to include(admin.person.id)
      end

      it "displays preferred email in label with user email priority" do
        user_with_emails = create(:user, email: "login@corp.com")
        user_with_emails.person.update!(email: "personal@example.com", email_2: "alt@example.com")
        get "/search/person", params: { q: "login@corp" }
        json = JSON.parse(response.body)
        match = json.find { |r| r["id"] == user_with_emails.person.id }
        expect(match["label"]).to include("login@corp.com")
      end

      it "falls back to person email when no user email" do
        person = create(:person, first_name: "Eve", last_name: "Nolan", email: "eve@personal.com", user: nil)
        get "/search/person", params: { q: "Eve" }
        json = JSON.parse(response.body)
        match = json.find { |r| r["id"] == person.id }
        expect(match["label"]).to include("eve@personal.com")
      end

      it "falls back to email_2 when no user or person email" do
        person = create(:person, first_name: "Fay", last_name: "Park", email: nil, email_2: "fay@backup.com", user: nil)
        get "/search/person", params: { q: "Fay" }
        json = JSON.parse(response.body)
        match = json.find { |r| r["id"] == person.id }
        expect(match["label"]).to include("fay@backup.com")
      end

      it "returns results matched by email_2 even when label shows a different email" do
        user_with_alt = create(:user, email: "primary@corp.com")
        user_with_alt.person.update!(email: "work@corp.com", email_2: "secret@hidden.org")
        get "/search/person", params: { q: "secret@hidden" }
        json = JSON.parse(response.body)
        match = json.find { |r| r["id"] == user_with_alt.person.id }
        expect(match).to be_present
        expect(match["label"]).not_to include("secret@hidden")
      end

      it "returns results matched by user email even when label shows person email" do
        person = create(:person, first_name: "Gina", last_name: "Reyes", email: "gina@personal.com", user: nil)
        login_user = create(:user, email: "greyes@company.com", person: person)
        get "/search/person", params: { q: "greyes@company" }
        json = JSON.parse(response.body)
        match = json.find { |r| r["id"] == person.id }
        expect(match).to be_present
      end

      it "handles multi-word queries" do
        get "/search/person", params: { q: "Alice Smith" }
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["label"]).to include("Alice")
      end

      it "excludes specified IDs" do
        get "/search/person", params: { q: "Smith", exclude: alice.id.to_s }
        json = JSON.parse(response.body)
        ids = json.map { |r| r["id"] }
        expect(ids).not_to include(alice.id)
        expect(ids).to include(bob.id)
      end

      it "returns empty array for blank query" do
        get "/search/person", params: { q: "" }
        expect(JSON.parse(response.body)).to eq([])
      end

      it "returns results in alphabetical order" do
        get "/search/person", params: { q: "Smith" }
        json = JSON.parse(response.body)
        names = json.map { |r| r["label"] }
        expect(names).to eq(names.sort)
      end
    end
  end

  describe "GET /search/invalid" do
    before { sign_in admin }

    it "returns forbidden for unknown models" do
      get "/search/invalid", params: { q: "test" }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
