require "rails_helper"

RSpec.describe "Logging an incoming communication", type: :system, js: true do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "reveals the responded checkbox only when the direction is incoming" do
    visit new_notification_path

    expect(page).not_to have_field("notification[responded]")

    check "notification[direction]", allow_label_click: true

    expect(page).to have_field("notification[responded]")

    uncheck "notification[direction]", allow_label_click: true

    expect(page).not_to have_field("notification[responded]")
  end
end
