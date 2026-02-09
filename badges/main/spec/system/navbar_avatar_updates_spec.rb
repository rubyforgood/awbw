require "rails_helper"

RSpec.describe "Navbar avatar behavior", type: :system do
  let(:user) { create(:user) }
  let!(:person) { create(:person, user: user) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in user
  end

  context "when uploading an avatar" do
    it "updates the navbar avatar after person avatar change" do
      visit edit_person_path(person)

      attach_file(
        "person_avatar",
        Rails.root.join("spec/fixtures/files/sample.png"),
        make_visible: true
      )

      click_button "Save changes"

      expect(page).to have_current_path(person_path(person), wait: 5)

      person.reload
      expect(person.avatar).to be_attached

      profile_img = find("#person_#{person.id}_avatar_image")
      expect(profile_img[:src]).to include(person.avatar.filename.to_s)

      avatar_img = find("#avatar-image")
      expect(avatar_img[:src]).to include(person.avatar.filename.to_s)
    end
  end

  context "when removing an avatar" do
    before do
      person.avatar.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
    end

    it "removes the avatar and updates the navbar" do
      visit edit_person_path(person)

      check "person__destroy"
      click_button "Save changes"

      expect(page).to have_current_path(person_path(person), wait: 5)

      person.reload
      expect(person.avatar).not_to be_attached

      avatar_img = find("#avatar-image")
      expect(avatar_img[:src]).to include("missing")
    end
  end
end
