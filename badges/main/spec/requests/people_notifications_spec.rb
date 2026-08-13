require "rails_helper"

RSpec.describe "Person notifications", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "PATCH /people/:id logging a notification" do
    it "creates a manual notification log from nested attributes" do
      expect {
        patch person_path(person), params: {
          person: {
            notifications_attributes: { "0" => { channel: "phone", email_subject: "Left a voicemail" } }
          }
        }
      }.to change { person.notifications.count }.by(1)

      notification = person.notifications.order(:created_at).last
      expect(notification.channel).to eq("phone")
      expect(notification.kind).to eq("manual_log")
      expect(notification.email_subject).to eq("Left a voicemail")
      expect(notification.recipient_email).to eq(person.preferred_email)
      expect(notification.noticeable).to eq(person)
    end

    it "logs an incoming communication when the direction is set" do
      patch person_path(person), params: {
        person: {
          notifications_attributes: { "0" => { channel: "phone", email_subject: "They called us", direction: "incoming" } }
        }
      }

      expect(person.notifications.order(:created_at).last).to be_incoming
    end

    it "ignores a blank notification with no note" do
      expect {
        patch person_path(person), params: {
          person: {
            notifications_attributes: { "0" => { channel: "email", email_subject: "" } }
          }
        }
      }.not_to change(Notification, :count)
    end
  end

  describe "PATCH /people/:id editing a logged notification" do
    let!(:log) do
      create(:notification, noticeable: person, sender: admin, recipient_email: person.preferred_email,
                            channel: "phone", email_subject: "Left a voicemail",
                            kind: "manual_log", recipient_role: "person", notification_type: 0)
    end

    it "updates an existing manual notification log in place" do
      patch person_path(person), params: {
        person: {
          notifications_attributes: { "0" => { id: log.id, channel: "email", email_subject: "Sent a reminder" } }
        }
      }

      log.reload
      expect(log.channel).to eq("email")
      expect(log.email_subject).to eq("Sent a reminder")
    end

    it "removes a logged notification when marked for destruction" do
      expect {
        patch person_path(person), params: {
          person: {
            notifications_attributes: { "0" => { id: log.id, _destroy: "1" } }
          }
        }
      }.to change { person.notifications.count }.by(-1)
    end

    it "keeps the admin's unsaved edit in the re-rendered form when the save fails validation" do
      patch person_path(person), params: {
        person: {
          notifications_attributes: { "0" => { id: log.id, channel: "not-a-channel", email_subject: "Edited subject" } }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      # The re-rendered field shows the submitted value, not the stale DB one.
      expect(response.body).to include("Edited subject")
      expect(response.body).not_to include("Left a voicemail")
      expect(log.reload.email_subject).to eq("Left a voicemail")
    end
  end

  describe "GET /people/:id/edit" do
    it "lists past communications addressed to the person" do
      person = create(:person, user: nil, email: "comms@example.com")
      create(:notification, recipient_email: "comms@example.com", email_subject: "Welcome aboard",
                            kind: "manual_log", recipient_role: "person", notification_type: 0)

      get edit_person_path(person)

      expect(response.body).to include("Communications")
      expect(response.body).to include("Welcome aboard")
    end

    it "makes a hand-noted communication editable but keeps an autoemail view-only" do
      hand_noted = create(:notification, noticeable: person, sender: admin,
                          recipient_email: person.preferred_email, email_subject: "Called them",
                          channel: "email", kind: "manual_log", recipient_role: "person", notification_type: 0)
      autoemail = create(:notification, noticeable: person, sender: nil,
                        recipient_email: person.preferred_email, email_subject: "Automated blast",
                        channel: "autoemail", kind: "event_registration_confirmation",
                        recipient_role: "person", notification_type: 0)

      get edit_person_path(person)

      # Both are shown...
      expect(response.body).to include("Called them")
      expect(response.body).to include("Automated blast")
      # ...but only the hand-noted one gets an editable nested-attributes field.
      id_fields = Nokogiri::HTML(response.body)
        .css('input[name*="notifications_attributes"][name$="[id]"]')
        .map { |input| input["value"] }
      expect(id_fields).to include(hand_noted.id.to_s)
      expect(id_fields).not_to include(autoemail.id.to_s)
    end
  end
end
