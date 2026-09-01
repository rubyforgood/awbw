require "rails_helper"

RSpec.describe "/staff_taggings", type: :request do
  let(:admin) { create(:user, :admin, :with_person) }
  let(:turbo_headers) { { "Turbo-Frame" => "staff_taggings_results", "Accept" => "text/html" } }

  describe "GET /staff_taggings (index)" do
    context "as an admin" do
      before { sign_in admin }

      it "lists staff taggings" do
        tag = create(:staff_tag, name: "Highlight roster")
        person = create(:person, first_name: "Ada", last_name: "Tagged")
        create(:staff_tagging, staff_tag: tag, staff_taggable: person)

        get staff_taggings_path, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ada Tagged")
        expect(response.body).to include("Highlight roster")
      end

      it "filters by staff tag" do
        wanted = create(:staff_tag, name: "Wanted")
        other = create(:staff_tag, name: "Other")
        create(:staff_tagging, staff_tag: wanted, staff_taggable: create(:person, first_name: "Keep", last_name: "Me"))
        create(:staff_tagging, staff_tag: other, staff_taggable: create(:person, first_name: "Drop", last_name: "Me"))

        get staff_taggings_path, params: { staff_tag_ids: wanted.id }, headers: turbo_headers

        expect(response.body).to include("Keep Me")
        expect(response.body).not_to include("Drop Me")
      end

      it "filters by marked status" do
        create(:staff_tagging, :marked, staff_taggable: create(:person, first_name: "Marked", last_name: "One"))
        create(:staff_tagging, staff_taggable: create(:person, first_name: "Plain", last_name: "One"))

        get staff_taggings_path, params: { marked: "true" }, headers: turbo_headers

        expect(response.body).to include("Marked One")
        expect(response.body).not_to include("Plain One")
      end

      it "labels the mark column with the tag's mark label when filtered to one tag" do
        tag = create(:staff_tag, name: "Cohort", mark_label: "Confirmed")
        create(:staff_tagging, staff_tag: tag)

        get staff_taggings_path, params: { staff_tag_ids: [ tag.id ] }, headers: turbo_headers

        expect(response.body).to include("Confirmed")
      end

      it "searches by person name" do
        create(:staff_tagging, staff_taggable: create(:person, first_name: "Alice", last_name: "Xylophone"))
        create(:staff_tagging, staff_taggable: create(:person, first_name: "Bob", last_name: "Quartz"))

        get staff_taggings_path, params: { query: "Xylophone" }, headers: turbo_headers

        expect(response.body).to include("Alice Xylophone")
        expect(response.body).not_to include("Bob Quartz")
      end

      it "searches by affiliated organization name" do
        person = create(:person, first_name: "Org", last_name: "Member")
        org = create(:organization, name: "Distinctive Org")
        create(:affiliation, person: person, organization: org)
        create(:staff_tagging, staff_taggable: person)
        create(:staff_tagging, staff_taggable: create(:person, first_name: "No", last_name: "Org"))

        get staff_taggings_path, params: { query: "Distinctive Org" }, headers: turbo_headers

        expect(response.body).to include("Org Member")
        expect(response.body).not_to include("No Org")
      end

      it "searches comments and communications content" do
        commented = create(:staff_tagging, staff_taggable: create(:person, first_name: "Has", last_name: "Comment"))
        create(:comment, commentable: commented, body: "escalated after a phone call")
        messaged = create(:staff_tagging, staff_taggable: create(:person, first_name: "Has", last_name: "Message"))
        create(:notification, noticeable: messaged, email_subject: "escalated follow-up")
        create(:staff_tagging, staff_taggable: create(:person, first_name: "No", last_name: "Content"))

        get staff_taggings_path, params: { content: "escalated" }, headers: turbo_headers

        expect(response.body).to include("Has Comment")
        expect(response.body).to include("Has Message")
        expect(response.body).not_to include("No Content")
      end

      it "filters by multiple staff tags at once" do
        tag_a = create(:staff_tag, name: "Alpha")
        tag_b = create(:staff_tag, name: "Bravo")
        create(:staff_tagging, staff_tag: tag_a, staff_taggable: create(:person, first_name: "In", last_name: "Alpha"))
        create(:staff_tagging, staff_tag: tag_b, staff_taggable: create(:person, first_name: "In", last_name: "Bravo"))
        create(:staff_tagging, staff_tag: create(:staff_tag, name: "Other"), staff_taggable: create(:person, first_name: "In", last_name: "Other"))

        get staff_taggings_path, params: { staff_tag_ids: [ tag_a.id, tag_b.id ] }, headers: turbo_headers

        expect(response.body).to include("In Alpha")
        expect(response.body).to include("In Bravo")
        expect(response.body).not_to include("In Other")
      end
    end

    context "as a non-admin" do
      it "forbids the index" do
        sign_in create(:user, super_user: false)
        get staff_taggings_path
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe "POST /staff_taggings (create)" do
    before { sign_in admin }

    it "tags a person with a staff tag" do
      person = create(:person)
      tag = create(:staff_tag)

      expect {
        post staff_taggings_path, params: { staff_tagging: { person_id: person.id, staff_tag_id: tag.id } }
      }.to change(StaffTagging, :count).by(1)

      expect(response).to redirect_to(staff_taggings_path)
      expect(StaffTagging.last.staff_taggable).to eq(person)
      expect(StaffTagging.last.staff_tag).to eq(tag)
    end

    it "rejects a tagging with no person" do
      tag = create(:staff_tag)

      expect {
        post staff_taggings_path, params: { staff_tagging: { person_id: "", staff_tag_id: tag.id } }
      }.not_to change(StaffTagging, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates the tagging already marked when the slider is on" do
      person = create(:person)
      tag = create(:staff_tag)

      post staff_taggings_path, params: { staff_tagging: { person_id: person.id, staff_tag_id: tag.id, marked: "1" } }

      expect(StaffTagging.last).to be_marked
    end
  end

  describe "GET /staff_taggings/:id/edit" do
    let(:staff_tag)     { create(:staff_tag, name: "VIP") }
    let(:staff_tagging) { create(:staff_tagging, staff_tag: staff_tag) }

    context "as an admin" do
      before { sign_in admin }

      it "renders the tag select plus the combined comments and communications section" do
        get edit_staff_tagging_path(staff_tagging)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edit staff tagging")
        expect(response.body).to include("VIP")
        expect(response.body).to include("Comments &amp; communications")
        expect(response.body).to include("Add comment")
        expect(response.body).to include("Add communication")
      end
    end

    context "as a non-admin" do
      it "redirects to root" do
        sign_in create(:user)

        get edit_staff_tagging_path(staff_tagging)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /staff_taggings/:id" do
    let(:staff_tag)     { create(:staff_tag, name: "VIP") }
    let(:staff_tagging) { create(:staff_tagging, staff_tag: staff_tag) }
    let(:person)        { staff_tagging.staff_taggable }

    before { sign_in admin }

    it "saves a new comment authored by the current user" do
      expect {
        patch staff_tagging_path(staff_tagging), params: {
          staff_tagging: { comments_attributes: { "0" => { topic: "Why", body: "Flagged VIP after a call" } } }
        }
      }.to change { staff_tagging.comments.count }.by(1)

      comment = staff_tagging.comments.order(:created_at).last
      expect(comment.body).to eq("Flagged VIP after a call")
      expect(comment.created_by).to eq(admin)
    end

    it "logs a communication filed against the tagging, addressed to the person" do
      expect {
        patch staff_tagging_path(staff_tagging), params: {
          staff_tagging: { notifications_attributes: { "0" => { email_subject: "Called about VIP status" } } }
        }
      }.to change { staff_tagging.notifications.count }.by(1)

      note = staff_tagging.notifications.last
      expect(note.noticeable).to eq(staff_tagging)
      expect(note.email_subject).to eq("Called about VIP status")
      expect(note.recipient_email).to eq(person.preferred_email.presence || "n/a")
    end

    it "changes which tag the tagging carries" do
      person = create(:person)
      new_tag = create(:staff_tag)
      tagging = create(:staff_tagging, staff_tag: create(:staff_tag), staff_taggable: person)

      patch staff_tagging_path(tagging), params: {
        return_to: "staff_taggings", staff_tagging: { staff_tag_id: new_tag.id }
      }

      expect(response).to redirect_to(staff_taggings_path)
      expect(tagging.reload.staff_tag).to eq(new_tag)
    end

    it "rejects moving a tagging onto a tag the person already carries" do
      person = create(:person)
      tag_a = create(:staff_tag)
      tag_b = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag_b, staff_taggable: person)
      tagging = create(:staff_tagging, staff_tag: tag_a, staff_taggable: person)

      patch staff_tagging_path(tagging), params: { staff_tagging: { staff_tag_id: tag_b.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(tagging.reload.staff_tag).to eq(tag_a)
    end

    it "marks the tagging" do
      patch staff_tagging_path(staff_tagging), params: {
        return_to: "staff_taggings", staff_tagging: { staff_tag_id: staff_tag.id, marked: "1" }
      }

      expect(staff_tagging.reload).to be_marked
    end
  end

  describe "PATCH /staff_taggings/:id/toggle_marked" do
    before { sign_in admin }

    it "checks the tagging off from the index and answers a turbo stream" do
      tagging = create(:staff_tagging)

      patch toggle_marked_staff_tagging_path(tagging), params: { value: "1" }, as: :turbo_stream

      expect(tagging.reload).to be_marked
      expect(response.media_type).to eq(Mime[:turbo_stream])
    end

    it "unchecks it when value is 0" do
      tagging = create(:staff_tagging, :marked)

      patch toggle_marked_staff_tagging_path(tagging), params: { value: "0" }, as: :turbo_stream

      expect(tagging.reload).not_to be_marked
    end
  end

  describe "PATCH /staff_taggings/:id/save_note" do
    before { sign_in admin }

    it "creates a comment from the inline note" do
      tagging = create(:staff_tagging)

      expect {
        patch save_note_staff_tagging_path(tagging), params: { note: "Called them" }
      }.to change { tagging.comments.count }.by(1)

      expect(tagging.comments.first.body).to eq("Called them")
    end

    it "edits the latest comment instead of piling up new ones" do
      tagging = create(:staff_tagging)
      create(:comment, commentable: tagging, body: "first")

      expect {
        patch save_note_staff_tagging_path(tagging), params: { note: "edited" }
      }.not_to change { tagging.comments.count }

      expect(tagging.comments.first.body).to eq("edited")
    end
  end

  describe "DELETE /staff_taggings/:id" do
    before { sign_in admin }

    it "removes a tagging" do
      tagging = create(:staff_tagging)

      expect {
        delete staff_tagging_path(tagging)
      }.to change(StaffTagging, :count).by(-1)
      expect(response).to redirect_to(staff_taggings_path)
    end
  end
end
