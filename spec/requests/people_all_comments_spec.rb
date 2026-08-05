require "rails_helper"

RSpec.describe "Person aggregated comments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:frame_headers) { { "Turbo-Frame" => "person_comments_results" } }

  describe "GET /people/:id/all_comments" do
    before { sign_in admin }

    it "renders the page shell with the composer and search boxes" do
      get all_comments_person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("All comments")
      expect(response.body).to include("aggregated_comment_composer")
      expect(response.body).to include("person_comments_results")
    end

    it "shows comments from the person, their registrations, scholarships, CE, and user account in the results frame" do
      create(:comment, commentable: person, body: "Profile note")

      registration = create(:event_registration, registrant: person)
      create(:comment, commentable: registration, body: "Registration note")

      scholarship = create(:scholarship, recipient: person)
      create(:comment, commentable: scholarship, body: "Scholarship note")

      ce = create(:continuing_education_registration, event_registration: registration)
      create(:comment, commentable: ce, body: "CE note")

      create(:comment, commentable: person.user, body: "Account note")

      get all_comments_person_path(person), headers: frame_headers

      expect(response.body).to include("Profile note", "Registration note", "Scholarship note", "CE note", "Account note")
    end

    it "filters to a single source" do
      create(:comment, commentable: person, body: "Profile note")
      registration = create(:event_registration, registrant: person)
      create(:comment, commentable: registration, body: "Registration note")

      get all_comments_person_path(person, source: "EventRegistration"), headers: frame_headers

      expect(response.body).to include("Registration note")
      expect(response.body).not_to include("Profile note")
    end

    it "filters by keyword across body and topic" do
      create(:comment, commentable: person, body: "Called the family", topic: "Outreach")
      create(:comment, commentable: person, body: "Sent the packet", topic: "Mailing")

      get all_comments_person_path(person, query: "family"), headers: frame_headers

      expect(response.body).to include("Called the family")
      expect(response.body).not_to include("Sent the packet")
    end

    it "filters by author" do
      author = create(:user, :admin, first_name: "Zelda", last_name: "Vance")
      create(:comment, commentable: person, body: "By Zelda", created_by: author, updated_by: author)
      create(:comment, commentable: person, body: "By someone else")

      get all_comments_person_path(person, author_id: author.id), headers: frame_headers

      expect(response.body).to include("By Zelda")
      expect(response.body).not_to include("By someone else")
    end

    it "filters to flagged only" do
      create(:comment, commentable: person, body: "Plain note")
      create(:comment, :flagged, commentable: person, body: "Flagged note")

      get all_comments_person_path(person, flagged: "1"), headers: frame_headers

      expect(response.body).to include("Flagged note")
      expect(response.body).not_to include("Plain note")
    end
  end

  describe "authorization" do
    it "forbids non-admins" do
      sign_in create(:user)
      get all_comments_person_path(person)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "adding a comment from the aggregated composer" do
    before { sign_in admin }

    it "files a note against the record named by the composer's signed GlobalID and prepends it to the feed" do
      scholarship = create(:scholarship, recipient: person)

      expect {
        post person_comments_path(person),
             params: { aggregated: "1", for_person_id: person.id,
                       commentable_sgid: scholarship.to_sgid.to_s, comment: { body: "Scholarship follow-up" } },
             as: :turbo_stream
      }.to change(scholarship.comments, :count).by(1)

      expect(response.body).to include("aggregated_comments_list")
      expect(response.body).to include("Scholarship follow-up")
    end

    it "files a note against a CE registration named by a signed GlobalID" do
      registration = create(:event_registration, registrant: person)
      ce = create(:continuing_education_registration, event_registration: registration)

      expect {
        post person_comments_path(person),
             params: { aggregated: "1", for_person_id: person.id,
                       commentable_sgid: ce.to_sgid.to_s, comment: { body: "CE follow-up" } },
             as: :turbo_stream
      }.to change(ce.comments, :count).by(1)
    end
  end

  describe "editing a comment inline from the aggregated feed" do
    before { sign_in admin }

    it "updates the body and re-renders the row" do
      comment = create(:comment, commentable: person, body: "Original")

      patch person_comment_path(person, comment),
            params: { aggregated: "1", for_person_id: person.id, comment: { body: "Edited" } },
            as: :turbo_stream

      expect(comment.reload.body).to eq("Edited")
      expect(response.body).to include("Edited")
    end
  end
end
