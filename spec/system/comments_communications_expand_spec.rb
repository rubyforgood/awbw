require "rails_helper"

RSpec.describe "Comments & communications expandable rows", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }
  let(:long_body) { "Long note. " * 80 }

  before do
    create(:comment, commentable: person, topic: "Phone call", body: long_body, created_by: admin, created_at: 2.days.ago)
    create(:notification, noticeable: person, recipient_email: "primary@example.com", email_subject: "Welcome",
                          email_body_text: long_body, kind: "manual_log", channel: "email", recipient_role: "person",
                          notification_type: 0, created_at: 1.day.ago)
    sign_in admin
    visit edit_person_path(person)
  end

  scenario "a row's chevron unclamps just that row" do
    within "#comments-section" do
      expect(page).to have_css("[data-expandable-card-target='body'].line-clamp-2", count: 2)

      first("button[aria-label='Show full entry']").click

      expect(page).to have_css("[data-expandable-card-target='body'].line-clamp-2", count: 1)
    end
  end

  scenario "expand all unclamps every row and collapse all restores them" do
    within "#comments-section" do
      click_button "Expand all"
      expect(page).to have_no_css("[data-expandable-card-target='body'].line-clamp-2")

      click_button "Collapse all"
      expect(page).to have_css("[data-expandable-card-target='body'].line-clamp-2", count: 2)
    end
  end

  scenario "hovering a communication row shows its subject alongside the body" do
    within "#comments-section" do
      expect(page).to have_css("[title^='Welcome — Long note.']")
    end
  end
end
