require "rails_helper"

RSpec.describe "Comments & communications person scope", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Aisha", last_name: "Sharma") }
  let(:other) { create(:person, first_name: "Bo", last_name: "Lin") }

  before do
    create(:comment, commentable: person, body: "Schedule note for Aisha", created_by: admin)
    create(:comment, commentable: other, body: "Schedule note for Bo", created_by: admin)
    sign_in admin
    visit comments_and_communications_path(person_id: person.id)
    # Turbo never cancels the frame's lazy load, so a filter typed before it lands is overwritten by it.
    expect(page).to have_css("turbo-frame#comments_and_communications_results[complete]", text: "Schedule note for Aisha")
  end

  scenario "filtering a person's feed keeps it on that person" do
    # Typing while the lazy first load is still in flight races it for the frame.
    expect(page).to have_css("turbo-frame#comments_and_communications_results[complete]", text: "Schedule note for Aisha")
    fill_in "query", with: "Schedule"

    expect(page).to have_css("turbo-frame#comments_and_communications_results[src*='query=Schedule'][complete]")
    within "turbo-frame#comments_and_communications_results" do
      expect(page).to have_content("Schedule note for Aisha")
      expect(page).to have_no_content("Schedule note for Bo")
    end
  end

  scenario "the New comment button beside the name opens the composer" do
    expect(page).to have_no_css("[data-panel-toggle-name='comment'][data-panel-toggle-target='panel']", visible: true)

    click_button "New comment"

    expect(page).to have_css("[data-panel-toggle-name='comment'][data-panel-toggle-target='panel']", visible: true)
  end

  scenario "clearing filters on a person's feed returns to everyone, header included" do
    click_link "Clear filters"

    expect(page).to have_css("h1", text: "Everyone")
    within "turbo-frame#comments_and_communications_results" do
      expect(page).to have_content("Schedule note for Bo")
    end
  end
end
