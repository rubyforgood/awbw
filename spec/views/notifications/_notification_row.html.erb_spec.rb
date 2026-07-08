require "rails_helper"

RSpec.describe "notifications/_notification_row", type: :view do
  let(:notification) do
    build_stubbed(:notification, channel: "phone", email_subject: "Called them",
                  email_body_text: "Left a voicemail about the deadline")
  end

  it "shows the channel icon, subject, and body when show_body is true" do
    render partial: "notifications/notification_row", locals: { notification: notification, show_body: true }

    expect(rendered).to have_css("i.fa-solid.fa-phone")
    expect(rendered).to include("Called them")
    expect(rendered).to include("Left a voicemail about the deadline")
  end

  it "hides the body (admin-only content) when show_body is false" do
    render partial: "notifications/notification_row", locals: { notification: notification, show_body: false }

    expect(rendered).to include("Called them")
    expect(rendered).not_to include("Left a voicemail about the deadline")
  end
end
