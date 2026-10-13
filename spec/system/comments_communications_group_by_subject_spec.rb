require "rails_helper"

RSpec.describe "Comments & communications group-by-subject toggle", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, email: "primary@example.com") }

  def communication(subject, **attrs)
    create(:notification, noticeable: person, recipient_email: "primary@example.com", email_subject: subject,
                          kind: "manual_log", channel: "email", recipient_role: "person",
                          notification_type: 0, **attrs)
  end

  scenario "clusters a comment topic and an email subject that match, then restores the flat list" do
    create(:comment, commentable: person, topic: "Facilitator affiliation",
                     body: "Confirmed by phone.", created_by: admin, created_at: 3.days.ago)
    communication("Facilitator affiliation", created_at: 1.day.ago)
    create(:comment, commentable: person, topic: "Promotion", body: "Promoted internally.",
                     created_by: admin, created_at: 2.days.ago)

    sign_in admin
    visit edit_person_path(person)

    within "#comments-section" do
      expect(page).to have_content("Comments & communications")
      expect(page).not_to have_content("2 items")

      find("label", text: "Group by subject").click

      # The comment and communication that share "Facilitator affiliation" group together.
      expect(page).to have_content("Facilitator affiliation")
      expect(page).to have_content("2 items")
      expect(page).to have_content("Promotion")

      uncheck "#{person.model_name.param_key}-activity-list-group"
      expect(page).not_to have_content("2 items")
    end
  end
end
