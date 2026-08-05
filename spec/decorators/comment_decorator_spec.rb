require "rails_helper"

RSpec.describe CommentDecorator do
  describe "#source_label" do
    it "labels a profile comment" do
      comment = create(:comment, commentable: create(:person))
      expect(comment.decorate.source_label).to eq("Profile")
    end

    it "labels a user-account comment" do
      comment = create(:comment, commentable: create(:user))
      expect(comment.decorate.source_label).to eq("User account")
    end

    it "labels a registration comment with the event title" do
      registration = create(:event_registration)
      comment = create(:comment, commentable: registration)
      expect(comment.decorate.source_label).to include("Registration ·", registration.event.title)
    end

    it "labels an unallocated scholarship comment with its id" do
      scholarship = create(:scholarship)
      comment = create(:comment, commentable: scholarship)
      expect(comment.decorate.source_label).to eq("Scholarship ##{scholarship.id}")
    end

    it "labels an allocated scholarship comment with its event" do
      registration = create(:event_registration)
      scholarship = create(:scholarship, recipient: registration.registrant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      comment = create(:comment, commentable: scholarship)
      expect(Comment.find(comment.id).decorate.source_label).to include("Scholarship ·", registration.event.title)
    end

    it "labels a CE registration comment with the event title" do
      ce = create(:continuing_education_registration)
      comment = create(:comment, commentable: ce)
      expect(comment.decorate.source_label).to include("CE ·", ce.event_registration.event.title)
    end

    it "labels a topic subscription comment with its topic" do
      subscription = create(:topic_subscription)
      comment = create(:comment, commentable: subscription)
      expect(comment.decorate.source_label).to include("Subscription ·", subscription.topic_label)
    end
  end

  describe "#source_path" do
    it "points a profile comment at the person page" do
      person = create(:person)
      comment = create(:comment, commentable: person)
      expect(comment.decorate.source_path).to eq(Rails.application.routes.url_helpers.person_path(person))
    end
  end

  describe "#source_theme" do
    it "returns the scholarships theme for a scholarship comment" do
      comment = create(:comment, commentable: create(:scholarship))
      expect(comment.decorate.source_theme).to eq(:scholarships)
    end
  end
end
