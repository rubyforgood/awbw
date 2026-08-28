require "rails_helper"

RSpec.describe Communicable do
  # Every record that renders the combined comments-and-communications section
  # includes this, so the section can rely on the same three things everywhere.
  INCLUDING_MODELS = [
    Affiliation, ContinuingEducationRegistration, EventRegistration, Organization,
    Person, Scholarship, Story, StoryIdea, TopicSubscription, User, Workshop
  ].freeze

  it "is included by every record whose form renders the combined section" do
    expect(INCLUDING_MODELS).to all(include(described_class))
  end

  it "gives each of them a notifications association and a communications email" do
    INCLUDING_MODELS.each do |model|
      expect(model.reflect_on_association(:notifications).options[:as]).to eq(:noticeable), model.name
      expect(model.new).to respond_to(:communications_email), model.name
      expect(model.new).to respond_to(:communications_scope), model.name
    end
  end

  describe "stamping a nested communication's recipient" do
    it "addresses a hand-logged communication to the record's person" do
      registration = create(:event_registration)

      registration.update!(notifications_attributes: { "0" => { channel: "phone", email_subject: "Left a voicemail" } })

      expect(registration.notifications.last.recipient_email).to eq(registration.registrant.preferred_email)
    end

    it "falls back to n/a when the record has nobody to address" do
      workshop = create(:workshop, author: nil)

      workshop.update!(notifications_attributes: { "0" => { channel: "phone", email_subject: "Called the author" } })

      expect(workshop.notifications.last.recipient_email).to eq("n/a")
    end

    it "leaves an already-saved communication's recipient alone" do
      person = create(:person)
      logged = create(:notification, noticeable: person, recipient_email: "old@example.com",
                                     kind: "manual_log", channel: "phone", recipient_role: "person",
                                     notification_type: 0, email_subject: "Called")

      person.update!(first_name: "Renamed")

      expect(logged.reload.recipient_email).to eq("old@example.com")
    end

    it "does not load the association on a save that touches no communications" do
      person = create(:person)
      create(:notification, noticeable: person, recipient_email: person.preferred_email,
                            kind: "manual_log", channel: "phone", recipient_role: "person",
                            notification_type: 0, email_subject: "Called")
      person.reload

      person.update!(first_name: "Renamed")

      expect(person.notifications).not_to be_loaded
    end
  end
end
