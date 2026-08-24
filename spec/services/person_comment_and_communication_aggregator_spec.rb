require "rails_helper"

RSpec.describe PersonCommentAndCommunicationAggregator do
  let(:person) { create(:person, email: "primary@example.com", email_2: "secondary@example.com") }

  def comment_on(record, **attrs)
    create(:comment, commentable: record, **attrs)
  end

  def communication(email, **attrs)
    create(:notification, recipient_email: email, kind: "manual_log", channel: "email",
                          recipient_role: "person", notification_type: 0, **attrs)
  end

  describe "#entries" do
    it "interleaves the person's comments and communications newest first" do
      older_comment = comment_on(person, body: "Older note", created_at: 3.days.ago)
      comm = communication("primary@example.com", email_subject: "Middle message", created_at: 2.days.ago)
      newer_comment = comment_on(person, body: "Newer note", created_at: 1.day.ago)

      entries = described_class.new(person).entries

      expect(entries).to eq([ newer_comment, comm, older_comment ])
    end

    it "picks up comments on the person's other records and comms to any of their addresses" do
      registration = create(:event_registration, registrant: person)
      registration_comment = comment_on(registration, body: "About the registration")
      to_secondary = communication("secondary@example.com", email_subject: "Second address")
      comment_on(create(:person), body: "Someone else's note")
      communication("stranger@example.com", email_subject: "Not theirs")

      expect(described_class.new(person).entries).to contain_exactly(registration_comment, to_secondary)
    end
  end

  describe "shared filters" do
    it "matches the keyword against comment bodies and communication subjects" do
      match_comment = comment_on(person, body: "Discussed the scholarship deadline", topic: nil)
      match_comm = communication("primary@example.com", email_subject: "Scholarship award")
      comment_on(person, body: "Unrelated", topic: nil)
      communication("primary@example.com", email_subject: "Unrelated")

      entries = described_class.new(person, { query: "scholarship" }).entries

      expect(entries).to contain_exactly(match_comment, match_comm)
    end

    it "applies the date range to both kinds" do
      comment_on(person, body: "Too old", created_at: 10.days.ago)
      communication("primary@example.com", email_subject: "Too old", created_at: 10.days.ago)
      kept_comment = comment_on(person, body: "In range", created_at: 2.days.ago)
      kept_comm = communication("primary@example.com", email_subject: "In range", created_at: 2.days.ago)

      entries = described_class.new(person, { from: 5.days.ago.to_date.iso8601 }).entries

      expect(entries).to contain_exactly(kept_comment, kept_comm)
    end
  end

  describe "filters shared across both kinds" do
    it "matches a comment's topic and a communication's subject from one box" do
      topic_comment = comment_on(person, topic: "Scholarship", body: "Body says nothing")
      subject_comm = communication("primary@example.com", email_subject: "Scholarship award")
      comment_on(person, topic: "Other", body: "Scholarship in the body only")
      communication("primary@example.com", email_subject: "Something else")

      entries = described_class.new(person, { subject: "scholarship" }).entries

      expect(entries).to contain_exactly(topic_comment, subject_comm)
    end

    it "matches a comment's author and the staff member a communication was sent by" do
      author = create(:user, :admin)
      authored = comment_on(person, body: "Left by this admin", created_by: author)
      sent = communication("primary@example.com", email_subject: "Sent by this admin", sender: author)
      comment_on(person, body: "Someone else's note", created_by: create(:user, :admin))
      communication("primary@example.com", email_subject: "No sender")

      entries = described_class.new(person, { author_id: author.id }).entries

      expect(entries).to contain_exactly(authored, sent)
    end

    it "counts an incoming message as being from the person who sent it" do
      person_user = person.user
      incoming = communication(person_user.email, email_subject: "They wrote in", direction: "incoming")
      communication(person_user.email, email_subject: "We wrote out")

      entries = described_class.new(person, { author_id: person_user.id, kind: "communications" }).entries

      expect(entries).to contain_exactly(incoming)
    end

    it "matches a comment's commentable and a communication's noticeable from one picker" do
      registration = create(:event_registration, registrant: person)
      registration_comment = comment_on(registration, body: "On the registration")
      registration_comm = communication("primary@example.com", email_subject: "About the registration", noticeable: registration)
      comment_on(person, body: "On the profile")
      communication("primary@example.com", email_subject: "About the profile", noticeable: person)

      entries = described_class.new(person, { source: "EventRegistration" }).entries

      expect(entries).to contain_exactly(registration_comment, registration_comm)
    end

    it "treats a flagged comment and an unanswered incoming message as both needing follow-up" do
      flagged = comment_on(person, body: "Follow up", flagged: true)
      unanswered = communication("primary@example.com", email_subject: "They called", direction: "incoming", responded: false)
      comment_on(person, body: "Just a note")
      communication("primary@example.com", email_subject: "Answered", direction: "incoming", responded: true)

      entries = described_class.new(person, { follow_up: "needed" }).entries

      expect(entries).to contain_exactly(flagged, unanswered)
    end

    it "matches only communications for Responded, since a comment records no reply" do
      comment_on(person, body: "A note")
      answered = communication("primary@example.com", email_subject: "Answered", direction: "incoming", responded: true)

      expect(described_class.new(person, { follow_up: "responded" }).entries).to contain_exactly(answered)
    end
  end

  describe "kind selection" do
    let!(:comment) { comment_on(person, body: "Just a note") }
    let!(:comm) { communication("primary@example.com", email_subject: "A message") }

    it "narrows to one kind when asked outright" do
      expect(described_class.new(person, { kind: "comments" }).entries).to contain_exactly(comment)
      expect(described_class.new(person, { kind: "communications" }).entries).to contain_exactly(comm)
    end

    it "ignores an unrecognized kind" do
      expect(described_class.new(person, { kind: "bogus" }).entries).to contain_exactly(comment, comm)
    end

    it "drops comments for an email topic, the one filter they cannot answer" do
      expect(described_class.new(person, { email_topic: "Admin FYI (all)" }).entries).to be_empty
    end
  end

  describe "counts" do
    it "reports the unfiltered total and the flagged comment count" do
      comment_on(person, body: "Follow up", flagged: true)
      comment_on(person, body: "Just a note")
      communication("primary@example.com", email_subject: "A message")

      feed = described_class.new(person, { query: "follow" })

      expect(feed.total_count).to eq(3)
      expect(feed.flagged_count).to eq(1)
    end
  end
end
