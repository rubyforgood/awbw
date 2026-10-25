require "rails_helper"

RSpec.describe "Notification responded autosave", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:notification) { create(:notification, :incoming, kind: "manual_log", channel: "phone", email_subject: "They called") }

  before { sign_in admin }

  it "says Saved once the responded checkbox autosaves on the index" do
    visit notifications_path

    within("turbo-frame#notifications_results") do
      find("input[type=checkbox][name='notification[responded]']").check
      expect(page).to have_css("[data-field-name='notification[responded]']", text: "Saved")
    end
    expect(notification.reload).to be_responded
  end

  it "says Saved once the responded checkbox autosaves on the notification page" do
    visit notification_path(notification)

    find("input[type=checkbox][name='notification[responded]']").check

    expect(page).to have_css("[data-field-name='notification[responded]']", text: "Saved")
    expect(notification.reload).to be_responded
  end
end
