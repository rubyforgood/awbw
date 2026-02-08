require "rails_helper"

RSpec.describe "Navbar avatar behavior", type: :system do
  let(:user) { create(:user) }
  let!(:facilitator) { create(:facilitator, user: user) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in user
  end

  context "when uploading an avatar" do
    it "updates the navbar avatar after facilitator avatar change" do
      visit edit_facilitator_path(facilitator)

      attach_file(
        "facilitator_avatar",
        Rails.root.join("spec/fixtures/files/sample.png"),
        make_visible: true
      )

      click_button "Save changes"

      expect(page).to have_current_path(facilitator_path(facilitator), wait: 5)

      facilitator.reload
      expect(facilitator.avatar).to be_attached

      profile_img = find("#facilitator_#{facilitator.id}_avatar_image")
      expect(profile_img[:src]).to include(facilitator.avatar.filename.to_s)

      avatar_img = find("#avatar-image")
      expect(avatar_img[:src]).to include(facilitator.avatar.filename.to_s)
    end
  end

  context "when removing an avatar" do
    before do
      facilitator.avatar.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
    end

    it "removes the avatar and updates the navbar" do
      visit edit_facilitator_path(facilitator)

      check "facilitator__destroy"
      click_button "Save changes"

      expect(page).to have_current_path(facilitator_path(facilitator), wait: 5)

      facilitator.reload
      expect(facilitator.avatar).not_to be_attached

      avatar_img = find("#avatar-image")
      expect(avatar_img[:src]).to include("missing")
    end
  end
end
