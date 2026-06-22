require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /event_registrations/:id/comments" do
    let(:event)      { create(:event) }
    let(:registrant) { create(:person) }
    let(:reg)        { create(:event_registration, event:, registrant:) }

    it "renders a full page aggregating registration, person, user, and active-org comments" do
      registrant_user = registrant.user
      org = create(:organization, name: "Active Org")
      create(:affiliation, person: registrant, organization: org)

      create(:comment, commentable: reg, body: "Registration note")
      create(:comment, commentable: registrant, body: "Person note")
      create(:comment, commentable: registrant_user, body: "User note")
      create(:comment, commentable: org, body: "Org note")

      get event_registration_comments_path(reg)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Related comments")
      expect(response.body).to include(registrant.full_name)
      expect(response.body).to include("Registration note")
      expect(response.body).to include("Person note")
      expect(response.body).to include("User note")
      expect(response.body).to include("Org note")
    end

    it "excludes comments from organizations with no active affiliation" do
      inactive_org = create(:organization, name: "Former Org")
      create(:affiliation, person: registrant, organization: inactive_org, inactive: true)
      create(:comment, commentable: inactive_org, body: "Former org note")

      get event_registration_comments_path(reg)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("Former org note")
    end

    it "renders the bare list partial for turbo-frame requests" do
      create(:comment, commentable: reg, body: "Registration note")

      get event_registration_comments_path(reg), headers: { "Turbo-Frame" => "comments_list" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Registration note")
    end
  end

  describe "GET /comments" do
    it "renders every comment in the system regardless of commentable" do
      create(:comment, commentable: create(:person), body: "Person-wide note")
      create(:comment, commentable: create(:organization), body: "Org-wide note")

      get comments_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("All comments")
      expect(response.body).to include("Person-wide note")
      expect(response.body).to include("Org-wide note")
    end

    it "is restricted to admins" do
      sign_out admin
      sign_in create(:user)

      get comments_path

      expect(response).to redirect_to(root_path)
    end
  end
end
