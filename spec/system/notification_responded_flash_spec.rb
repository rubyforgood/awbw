require "rails_helper"

RSpec.describe "Notification responded flash", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:notification) { create(:notification, :incoming, kind: "manual_log", channel: "phone", email_subject: "They called") }

  before { sign_in admin }

  def responded_form_id
    ActionView::RecordIdentifier.dom_id(notification, :responded)
  end

  it "shows Saved after toggling responded on the index" do
    visit notifications_path

    within("turbo-frame#notifications_results") do
      find("form##{responded_form_id} button").click
    end

    expect(page).to have_css("#flash_now", text: "Saved", wait: 3)
    expect(notification.reload).to be_responded
  end

  it "shows Saved after toggling responded on the notification page" do
    visit notification_path(notification)

    find("form##{responded_form_id} button").click

    expect(page).to have_css("#flash_now", text: "Saved", wait: 3)
    expect(notification.reload).to be_responded
  end
end
