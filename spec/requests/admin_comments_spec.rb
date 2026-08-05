require "rails_helper"

RSpec.describe "Admin comments index", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:frame_headers) { { "Turbo-Frame" => "comments_results" } }

  describe "GET /admin/comments" do
    it "renders the page shell with search boxes including person and event filters" do
      sign_in admin
      get admin_comments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("comments_results")
      expect(response.body).to include("person_id", "event_id")
    end

    it "lists every comment in the results frame" do
      sign_in admin
      create(:comment, commentable: create(:person), body: "One")
      create(:comment, commentable: create(:workshop), body: "Two")

      get admin_comments_path, headers: frame_headers

      expect(response.body).to include("One", "Two")
    end

    it "filters to comments connected to a person" do
      sign_in admin
      target = create(:person)
      registration = create(:event_registration, registrant: target)
      create(:comment, commentable: registration, body: "Target registration note")
      create(:comment, commentable: create(:person), body: "Unrelated note")

      get admin_comments_path(person_id: target.id), headers: frame_headers

      expect(response.body).to include("Target registration note")
      expect(response.body).not_to include("Unrelated note")
    end

    it "filters to comments connected to an event" do
      sign_in admin
      registration = create(:event_registration)
      create(:comment, commentable: registration, body: "Event note")
      create(:comment, commentable: create(:event_registration), body: "Other event note")

      get admin_comments_path(event_id: registration.event_id), headers: frame_headers

      expect(response.body).to include("Event note")
      expect(response.body).not_to include("Other event note")
    end

    it "forbids non-admins" do
      sign_in create(:user)
      get admin_comments_path
      expect(response).to redirect_to(root_path)
    end
  end
end
