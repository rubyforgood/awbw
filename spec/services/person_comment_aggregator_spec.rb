require "rails_helper"

RSpec.describe PersonCommentAggregator do
  subject(:aggregator) { described_class.new(person) }

  let(:person) { create(:person) }

  describe "#comments" do
    it "gathers comments from the person, their registrations, scholarships, CE registrations, stories, story ideas, and user account" do
      profile_comment = create(:comment, commentable: person)

      registration = create(:event_registration, registrant: person)
      registration_comment = create(:comment, commentable: registration)

      scholarship = create(:scholarship, recipient: person)
      scholarship_comment = create(:comment, commentable: scholarship)

      ce_registration = create(:continuing_education_registration, event_registration: registration)
      ce_comment = create(:comment, commentable: ce_registration)

      subscription = create(:topic_subscription, person: person)
      subscription_comment = create(:comment, commentable: subscription)

      story = create(:story, author: person)
      story_comment = create(:comment, commentable: story)

      story_idea = create(:story_idea, created_by: person.user)
      story_idea_comment = create(:comment, commentable: story_idea)

      user_comment = create(:comment, commentable: person.user)

      expect(aggregator.comments).to contain_exactly(
        profile_comment, registration_comment, scholarship_comment, ce_comment, subscription_comment,
        story_comment, story_idea_comment, user_comment
      )
    end

    it "excludes comments left on unrelated records" do
      other_person = create(:person)
      create(:comment, commentable: other_person)
      mine = create(:comment, commentable: person)

      expect(aggregator.comments).to contain_exactly(mine)
    end

    it "returns comments newest first" do
      older = create(:comment, commentable: person, created_at: 2.days.ago)
      newer = create(:comment, commentable: person, created_at: 1.hour.ago)

      expect(aggregator.comments.to_a).to eq([ newer, older ])
    end

    it "returns an empty relation when the person has no comments and no user" do
      person_without_user = create(:person, user: nil)

      expect(described_class.new(person_without_user).comments).to be_empty
    end
  end
end
