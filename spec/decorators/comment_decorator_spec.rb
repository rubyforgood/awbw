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
    it "points a comment at its commentable's edit page, where it can be changed" do
      person = create(:person)
      comment = create(:comment, commentable: person)
      expect(comment.decorate.source_path).to eq(Rails.application.routes.url_helpers.edit_person_path(person))
    end

    it "points a scholarship comment at the scholarship's edit page" do
      scholarship = create(:scholarship)
      comment = create(:comment, commentable: scholarship)
      expect(comment.decorate.source_path).to eq(Rails.application.routes.url_helpers.edit_scholarship_path(scholarship))
    end
  end

  describe "#source_theme" do
    it "returns the scholarships theme for a scholarship comment" do
      comment = create(:comment, commentable: create(:scholarship))
      expect(comment.decorate.source_theme).to eq(:scholarships)
    end
  end

  describe "#type_chip" do
    it "renders a chat icon and a Com't label for parity with the Email chip" do
      chip = create(:comment).decorate.type_chip
      expect(chip).to include("fa-comment")
      expect(chip).to include("Com&#39;t")
    end
  end

  describe "#event / #event_registration" do
    it "resolves the event and registration for a registration comment" do
      registration = create(:event_registration)
      comment = create(:comment, commentable: registration)

      expect(comment.decorate.event).to eq(registration.event)
      expect(comment.decorate.event_registration).to eq(registration)
    end

    it "resolves the event through a CE registration comment" do
      ce = create(:continuing_education_registration)
      comment = create(:comment, commentable: ce)

      expect(comment.decorate.event).to eq(ce.event_registration.event)
      expect(comment.decorate.event_registration).to eq(ce.event_registration)
    end

    it "resolves the event through an allocated scholarship comment" do
      registration = create(:event_registration)
      scholarship = create(:scholarship, recipient: registration.registrant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      comment = create(:comment, commentable: scholarship)

      expect(Comment.find(comment.id).decorate.event).to eq(registration.event)
    end

    it "is nil for a comment that isn't about an event" do
      comment = create(:comment, commentable: create(:person))

      expect(comment.decorate.event).to be_nil
      expect(comment.decorate.event_registration).to be_nil
    end
  end

  describe "#event_chip" do
    it "links to the registration's edit page for an event comment" do
      registration = create(:event_registration)
      comment = create(:comment, commentable: registration)

      chip = comment.decorate.event_chip(linked: true)

      expect(chip).to include("<a")
      expect(chip).to include(Rails.application.routes.url_helpers.edit_event_registration_path(registration))
    end

    it "is blank for a comment that isn't about an event" do
      comment = create(:comment, commentable: create(:person))

      expect(comment.decorate.event_chip).to eq("")
    end
  end
end
