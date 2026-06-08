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
  end

  describe "GET /people/:person_id/comments" do
    it "renders the topic in bold followed by the body" do
      create(:comment, commentable: person, topic: "Follow up", body: "Called the family.")

      get person_comments_path(person)

      expect(response.body).to include('<div class="font-bold uppercase tracking-wide">Follow up</div>')
      expect(response.body).to include("Called the family.")
    end
  end
end
