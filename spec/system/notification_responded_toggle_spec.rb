require "rails_helper"

RSpec.describe "Notification responded toggle", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:fyi) { create(:notification, kind: "contact_us_fyi", responded: false, recipient_email: "fyi@example.com") }

  before { sign_in admin }

  def responded_form_id
    ActionView::RecordIdentifier.dom_id(fyi, :responded)
  end

  def responded_toggle
    find("form##{responded_form_id} button")
  end

  describe "on the index page" do
    it "marks responded when clicked" do
      visit notifications_path

      expect(responded_toggle["aria-pressed"]).to eq("false")

      responded_toggle.click

      expect(page).to have_css("form##{responded_form_id} button[aria-pressed='true']", wait: 5)
      expect(fyi.reload.responded).to be(true)
    end

    it "clears responded when clicked again" do
      fyi.update!(responded: true)

      visit notifications_path

      expect(responded_toggle["aria-pressed"]).to eq("true")

      responded_toggle.click

      expect(page).to have_css("form##{responded_form_id} button[aria-pressed='false']", wait: 5)
      expect(fyi.reload.responded).to be(false)
    end
  end

  describe "on the show page" do
    it "marks responded when clicked" do
      visit notification_path(fyi)

      expect(responded_toggle["aria-pressed"]).to eq("false")

      responded_toggle.click

      expect(page).to have_css("form##{responded_form_id} button[aria-pressed='true']", wait: 5)
      expect(fyi.reload.responded).to be(true)
    end

    it "clears responded when clicked again" do
      fyi.update!(responded: true)

      visit notification_path(fyi)

      expect(responded_toggle["aria-pressed"]).to eq("true")

      responded_toggle.click

      expect(page).to have_css("form##{responded_form_id} button[aria-pressed='false']", wait: 5)
      expect(fyi.reload.responded).to be(false)
    end
  end
end
