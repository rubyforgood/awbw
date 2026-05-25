require "rails_helper"

RSpec.describe "Notification responded toggle", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:fyi) { create(:notification, kind: "contact_us_fyi", responded: false, recipient_email: "fyi@example.com") }

  before { sign_in admin }

  def responded_checkbox
    find("input[type='checkbox'][name='notification[responded]']")
  end

  describe "on the index page" do
    it "auto-saves when an admin checks the box" do
      visit notifications_path

      expect(responded_checkbox).not_to be_checked

      responded_checkbox.check

      expect(page).to have_css("input[name='notification[responded]'].ring-green-300", wait: 5)
      expect(fyi.reload.responded).to be(true)
    end

    it "auto-saves when an admin unchecks the box" do
      fyi.update!(responded: true)

      visit notifications_path

      expect(responded_checkbox).to be_checked

      responded_checkbox.uncheck

      expect(page).to have_css("input[name='notification[responded]'].ring-green-300", wait: 5)
      expect(fyi.reload.responded).to be(false)
    end
  end

  describe "on the show page" do
    it "auto-saves when an admin checks the box" do
      visit notification_path(fyi)

      expect(responded_checkbox).not_to be_checked

      responded_checkbox.check

      expect(page).to have_css("input[name='notification[responded]'].ring-green-300", wait: 5)
      expect(fyi.reload.responded).to be(true)
    end

    it "auto-saves when an admin unchecks the box" do
      fyi.update!(responded: true)

      visit notification_path(fyi)

      expect(responded_checkbox).to be_checked

      responded_checkbox.uncheck

      expect(page).to have_css("input[name='notification[responded]'].ring-green-300", wait: 5)
      expect(fyi.reload.responded).to be(false)
    end
  end
end
