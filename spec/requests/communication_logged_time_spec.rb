require "rails_helper"

# A manually logged communication records a contact that already happened, so its
# date/time (created_at) is editable — staff can log a call/email after the fact
# with the time it actually occurred.
RSpec.describe "Editing a communication's logged date/time", type: :request do
  let(:admin) { create(:user, :admin, time_zone: "UTC") }
  let(:person) { create(:person) }

  before { sign_in admin }

  it "logs a communication after the fact with the given date/time (nested)" do
    backdated = 5.days.ago.change(sec: 0, usec: 0)

    patch person_path(person), params: {
      person: {
        notifications_attributes: { "0" => {
          channel: "phone", email_subject: "Called last week",
          created_at: backdated.utc.strftime("%Y-%m-%dT%H:%M")
        } }
      }
    }

    note = person.notifications.order(:created_at).last
    expect(note.email_subject).to eq("Called last week")
    expect(note.created_at).to be_within(1.minute).of(backdated)
  end

  it "logs a standalone communication with the given date/time" do
    backdated = 3.days.ago.change(sec: 0, usec: 0)

    expect {
      post notifications_path, params: {
        person_id: person.id,
        notification: {
          channel: "phone", email_subject: "Left a voicemail",
          created_at: backdated.utc.strftime("%Y-%m-%dT%H:%M")
        }
      }
    }.to change(Notification, :count).by(1)

    expect(Notification.order(:created_at).last.created_at).to be_within(1.minute).of(backdated)
  end

  it "updates an existing communication's logged date/time" do
    note = create(:notification, noticeable: person, sender: admin, recipient_email: person.preferred_email,
                                 channel: "phone", email_subject: "Left a voicemail", kind: "manual_log",
                                 recipient_role: "person", notification_type: 0)
    new_time = 2.days.ago.change(sec: 0, usec: 0)

    patch notification_path(note), params: {
      notification: { created_at: new_time.utc.strftime("%Y-%m-%dT%H:%M") }
    }

    expect(note.reload.created_at).to be_within(1.minute).of(new_time)
  end
end
