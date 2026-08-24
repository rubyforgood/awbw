require "rails_helper"

RSpec.describe "Person comments and communications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }

  describe "GET /people/:id/comments_and_communications" do
    before { sign_in admin }

    it "renders the page shell with the filter bar" do
      get comments_and_communications_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("All comments &amp; communications")
      # The shared filters, each answered on both models' own columns.
      expect(response.body).to include("Subject or topic")
      expect(response.body).to include("From or author")
      expect(response.body).to include("Attached to")
      expect(response.body).to include("Follow-up")
    end

    it "renders comments and communications together in the results frame" do
      create(:comment, commentable: person, body: "Internal staff note", created_by: admin)
      create(:notification, recipient_email: "primary@example.com", email_subject: "Welcome aboard",
                            kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)

      get comments_and_communications_person_path(person), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      expect(response.body).to include("Internal staff note")
      expect(response.body).to include("Welcome aboard")
    end

    it "starts the comment body flush under its topic instead of truncating it" do
      create(:comment, commentable: person, topic: "Topic line", body: "A note", created_by: admin)

      get comments_and_communications_person_path(person), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      body = Nokogiri::HTML(response.body).css("div").find { |div| div.text.strip == "A note" }
      expect(body["class"]).not_to include("truncate")
      # Topic and body share one flex column, so both start at the same left edge.
      expect(body.parent["class"]).to include("flex-1")
      expect(body.parent.text).to include("Topic line")
    end

    it "puts the attached record's chip on the headline row, above the body" do
      registration = create(:event_registration, registrant: person)
      create(:comment, commentable: registration, body: "On the registration", created_by: admin)

      get comments_and_communications_person_path(person), headers: { "Turbo-Frame" => "comments_and_communications_results" }

      chip = Nokogiri::HTML(response.body).at_css("a[href='#{edit_event_registration_path(registration)}']")
      body = Nokogiri::HTML(response.body).css("div").find { |div| div.text.strip == "On the registration" }
      expect(chip).to be_present
      # The chip closes the headline row; the body follows it as a full-width line.
      expect(chip.path < body.path).to be(true)
    end

    it "denies a non-admin" do
      sign_in create(:user)

      get comments_and_communications_person_path(person)

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "the combined section's link to the feed" do
    before { sign_in admin }

    it "offers one 'All comments & communications' link carrying the origin record" do
      get edit_person_path(person)

      expect(response.body).to include("All comments &amp; communications")
      expect(response.body).to include(CGI.escapeHTML(
        comments_and_communications_person_path(person, return_to_type: "Person", return_to_id: person.id)
      ))
      expect(response.body).not_to include(">All comments\n")
    end

    it "links to the registrant's feed from an event registration" do
      registration = create(:event_registration, registrant: person)

      get edit_event_registration_path(registration)

      expect(response.body).to include(CGI.escapeHTML(
        comments_and_communications_person_path(person, return_to_type: "EventRegistration", return_to_id: registration.id)
      ))
    end
  end
end
