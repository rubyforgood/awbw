require "rails_helper"

RSpec.describe "StaffTaggings", type: :request do
  let(:admin)         { create(:user, :with_person, super_user: true) }
  let(:staff_tag)     { create(:staff_tag, name: "VIP") }
  let(:staff_tagging) { create(:staff_tagging, staff_tag: staff_tag) }
  let(:person)        { staff_tagging.staff_taggable }

  describe "GET /staff_taggings/:id/edit" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the combined comments and communications section for the tagging" do
        get edit_staff_tagging_path(staff_tagging)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Staff tag: VIP")
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
  end
end
