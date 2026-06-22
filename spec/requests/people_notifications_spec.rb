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

  describe "GET /people/:id/edit" do
    it "lists past communications addressed to the person" do
      person = create(:person, user: nil, email: "comms@example.com")
      create(:notification, recipient_email: "comms@example.com", email_subject: "Welcome aboard",
                            kind: "manual_log", recipient_role: "person", notification_type: 0)

      get edit_person_path(person)

      expect(response.body).to include("Communications")
      expect(response.body).to include("Welcome aboard")
    end
  end
end
