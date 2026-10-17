require "rails_helper"

RSpec.describe "Comments & communications feed results controls", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }

  before do
    create(:comment, commentable: person, topic: "Phone call", body: "Talked through the schedule.", created_by: admin, created_at: 2.days.ago)
    create(:notification, noticeable: person, recipient_email: "primary@example.com", email_subject: "Welcome",
                          email_body_text: "Glad to have you.", kind: "manual_log", channel: "email", recipient_role: "person",
                          notification_type: 0, created_at: 1.day.ago)
    sign_in admin
    visit comments_and_communications_path(person_id: person.id)
  end

  scenario "collapse all hides every body and a row's chevron reopens it" do
    within "turbo-frame#comments_and_communications_results" do
      expect(page).to have_content("Talked through the schedule.")

      click_button "Collapse all"
      expect(page).to have_no_content("Talked through the schedule.")
      expect(page).to have_no_content("Glad to have you.")

      within("#comment_#{person.comments.first.id}") { click_button "Show full entry" }
      expect(page).to have_content("Talked through the schedule.")
    end
  end

  scenario "changing Show or Group by subject keeps collapsed rows and a row reopened on its own" do
    comment = person.comments.first

    within "turbo-frame#comments_and_communications_results" do
      click_button "Collapse all"
      within("#comment_#{comment.id}") { click_button "Show full entry" }
      expect(page).to have_content("Talked through the schedule.")

      select "Comments", from: "kind"
      expect(page).to have_no_content("Welcome")
      expect(page).to have_content("Talked through the schedule.")
      expect(page).to have_button("Expand all")

      select "All", from: "kind"
      expect(page).to have_content("Welcome")
      expect(page).to have_no_content("Glad to have you.")

      check "Group by subject"
      expect(page).to have_css("h3", text: "Welcome")
      expect(page).to have_no_content("Glad to have you.")
      expect(page).to have_content("Talked through the schedule.")
    end
  end

  scenario "the Show dropdown and Group by subject sit in the results header and filter the feed" do
    within "turbo-frame#comments_and_communications_results" do
      select "Comments", from: "kind"
      expect(page).to have_content("Phone call")
      expect(page).to have_no_content("Welcome")
      expect(page).to have_select("kind", selected: "Comments")

      check "Group by subject"
      expect(page).to have_css("h3", text: "Phone call")
      expect(page).to have_checked_field("Group by subject")
    end
  end
end
