require "rails_helper"

RSpec.describe "notifications/_notification_row", type: :view do
  let(:hand_noted) do
    build_stubbed(:notification, kind: "manual_log", channel: "phone", email_subject: "Called them",
                  email_body_text: "Left a voicemail about the deadline")
  end
  let(:autoemail) do
    build_stubbed(:notification, kind: "event_registration_confirmation", channel: "autoemail",
                  email_subject: "Registration confirmed", email_body_text: "Hello Kim, your spot is booked")
  end

  it "shows the channel icon and subject for a hand-noted communication" do
    render partial: "notifications/notification_row", locals: { notification: hand_noted, admin: true }

    expect(rendered).to have_css("i.fa-solid.fa-phone")
    expect(rendered).to include("Called them")
  end

  it "shows a hand-noted body only to admins, with the admin-only blue styling" do
    render partial: "notifications/notification_row", locals: { notification: hand_noted, admin: true }

    expect(rendered).to have_css("span.admin-only.bg-blue-100", text: "Left a voicemail about the deadline")
  end

  it "hides a hand-noted body from non-admins (no inline text, nothing to hover)" do
    render partial: "notifications/notification_row", locals: { notification: hand_noted, admin: false }

    expect(rendered).to include("Called them")
    expect(rendered).not_to include("Left a voicemail about the deadline")
  end

  it "shows an automated body to everyone, without admin styling, and in the hover title" do
    render partial: "notifications/notification_row", locals: { notification: autoemail, admin: false }

    expect(rendered).to include("Hello Kim, your spot is booked")
    expect(rendered).not_to have_css("span.admin-only")
    expect(rendered).to have_css("span[title*='Hello Kim, your spot is booked']")
  end
end
