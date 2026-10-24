require "rails_helper"

RSpec.describe CommentDecorator do
  describe "#source_title" do
    it "gives a profile comment the person's full name and email" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      comment = create(:comment, commentable: person)
      expect(comment.decorate.source_title).to eq("#{person.full_name} (ada@example.com)")
    end

    it "is just the full name when the person has no email" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
      comment = create(:comment, commentable: person)
      expect(comment.decorate.source_title).to eq(person.full_name)
    end

    it "names the registrant with their email on a registration comment" do
      registrant = create(:person, email: "reg@example.com")
      comment = create(:comment, commentable: create(:event_registration, registrant: registrant))
      expect(comment.decorate.source_title).to eq("#{registrant.full_name} (reg@example.com)")
    end

    it "is nil for a comment with no person behind it" do
      comment = create(:comment, commentable: create(:user))
      expect(comment.decorate.source_title).to be_nil
    end
  end

  describe "#source_label" do
    it "labels a profile comment with the person's name" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace")
      comment = create(:comment, commentable: person)
      expect(comment.decorate.source_label).to eq(person.full_name)
    end

    it "labels a user-account comment" do
      comment = create(:comment, commentable: create(:user))
      expect(comment.decorate.source_label).to eq("User account")
    end

    it "labels a registration comment with the registrant and the event title" do
      registration = create(:event_registration)
      comment = create(:comment, commentable: registration)
      expect(comment.decorate.source_label).to start_with("#{registration.registrant.full_name} · Registration ·")
      expect(comment.decorate.source_label).to include(registration.event.title)
    end

    it "labels an unallocated scholarship comment with its id" do
      scholarship = create(:scholarship)
      comment = create(:comment, commentable: scholarship)
      expect(comment.decorate.source_label).to eq("#{scholarship.recipient.full_name} · Scholarship ##{scholarship.id}")
    end

    it "labels an allocated scholarship comment with its event" do
      registration = create(:event_registration)
      scholarship = create(:scholarship, recipient: registration.registrant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      comment = create(:comment, commentable: scholarship)
      expect(Comment.find(comment.id).decorate.source_label).to include("Scholarship ·", registration.event.title)
    end

    it "labels a CE registration comment with the registrant and the event title" do
      ce = create(:continuing_education_registration)
      comment = create(:comment, commentable: ce)
      expect(comment.decorate.source_label).to start_with("#{ce.event_registration.registrant.full_name} · CE ·")
      expect(comment.decorate.source_label).to include(ce.event_registration.event.title)
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

  describe "#last_editor" do
    it "is whoever last updated the comment" do
      author = create(:user)
      editor = create(:user)
      comment = create(:comment, created_by: author, updated_by: editor)

      expect(comment.decorate.last_editor).to eq(editor)
    end

    it "falls back to the author for an unedited comment" do
      author = create(:user)
      comment = create(:comment, created_by: author, updated_by: nil)

      expect(comment.decorate.last_editor).to eq(author)
    end
  end

  describe "#edited_timestamp" do
    it "formats when the comment was last updated" do
      comment = build(:comment, updated_at: Time.zone.local(2026, 10, 17, 13, 5))

      expect(comment.decorate.edited_timestamp).to eq("10/17/2026 1:05 PM")
    end
  end
end
