require "rails_helper"

RSpec.describe Comment, "search scopes" do
  describe ".matching" do
    it "matches body or topic case-insensitively" do
      body_hit = create(:comment, body: "Called the FAMILY", topic: "x")
      topic_hit = create(:comment, body: "x", topic: "Family outreach")
      miss = create(:comment, body: "nothing", topic: "here")

      expect(Comment.matching("family")).to include(body_hit, topic_hit)
      expect(Comment.matching("family")).not_to include(miss)
    end
  end

  describe ".authored_by_user" do
    it "matches comments the user created or last edited" do
      author = create(:user, :admin)
      created = create(:comment, created_by: author, updated_by: create(:user))
      edited = create(:comment, created_by: create(:user), updated_by: author)
      miss = create(:comment)

      expect(Comment.authored_by_user(author.id)).to include(created, edited)
      expect(Comment.authored_by_user(author.id)).not_to include(miss)
    end
  end

  describe "date range" do
    it "filters created_on_or_after / created_on_or_before" do
      old = create(:comment, created_at: "2026-01-01 09:00")
      recent = create(:comment, created_at: "2026-06-01 09:00")

      expect(Comment.created_on_or_after("2026-05-01")).to include(recent)
      expect(Comment.created_on_or_after("2026-05-01")).not_to include(old)
      expect(Comment.created_on_or_before("2026-05-01")).to include(old)
      expect(Comment.created_on_or_before("2026-05-01")).not_to include(recent)
    end

    it "ignores an unparseable date" do
      comment = create(:comment)
      expect(Comment.created_on_or_after("not-a-date")).to include(comment)
    end
  end

  describe ".for_event" do
    it "gathers registration, CE, and scholarship comments for the event" do
      registration = create(:event_registration)
      reg_comment = create(:comment, commentable: registration)
      ce = create(:continuing_education_registration, event_registration: registration)
      ce_comment = create(:comment, commentable: ce)
      scholarship = create(:scholarship, recipient: registration.registrant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      schol_comment = create(:comment, commentable: scholarship)

      other = create(:comment, commentable: create(:event_registration))

      result = Comment.for_event(registration.event_id)
      expect(result).to include(reg_comment, ce_comment, schol_comment)
      expect(result).not_to include(other)
    end
  end
end
