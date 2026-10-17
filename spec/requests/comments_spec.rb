require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "POST /people/:person_id/comments" do
    it "creates a comment with a topic and body" do
      expect {
        post person_comments_path(person), params: { comment: { topic: "Follow up", body: "Called the family." } }
      }.to change(person.comments, :count).by(1)

      comment = person.comments.last
      expect(comment.topic).to eq("Follow up")
      expect(comment.body).to eq("Called the family.")
    end

    it "creates a comment flagged for follow-up" do
      post person_comments_path(person), params: { comment: { body: "Check back later.", flagged: "1" } }

      expect(person.comments.last).to be_flagged
    end
  end

  describe "PATCH /people/:person_id/comments/:id" do
    it "toggles the flagged state" do
      comment = create(:comment, commentable: person, body: "Called the family.")

      patch person_comment_path(person, comment), params: { comment: { flagged: "true" } }, as: :turbo_stream
      expect(comment.reload).to be_flagged
      expect(response.body).to include("text-orange-500")

      patch person_comment_path(person, comment), params: { comment: { flagged: "false" } }, as: :turbo_stream
      expect(comment.reload).not_to be_flagged
    end
  end

  describe "DELETE /comments/:id" do
    it "deletes the comment" do
      comment = create(:comment, commentable: person, body: "Filed by mistake.")

      expect {
        delete comment_path(comment), headers: { "HTTP_REFERER" => edit_person_path(person) }
      }.to change(Comment, :count).by(-1)
      expect(response).to redirect_to(edit_person_path(person))
    end

    it "forbids non-admins" do
      comment = create(:comment, commentable: person, body: "Staff only.")
      sign_in create(:user)

      expect { delete comment_path(comment) }.not_to change(Comment, :count)
    end
  end
end
