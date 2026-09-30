require "rails_helper"

# Form sections collapse to a summary, and plenty of links deep-link straight
# into one by URL fragment (a comment icon → #comments-section, the affiliation
# editor returning to #affiliations). A fragment never reaches the server, so
# app/frontend/javascript/details-fragment.js expands the section client-side.
RSpec.describe "Deep links into a collapsed form section", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person) }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
  end

  it "expands the comments section when the fragment points at it" do
    create(:comment, commentable: person, topic: "Facilitator affiliation",
                     body: "Confirmed by phone.", created_by: admin)

    visit edit_person_path(person, anchor: "comments-section")

    expect(page).to have_text("Confirmed by phone.", wait: 10)
  end

  it "expands the affiliations section when the fragment points at it" do
    create(:affiliation, person: person, organization: create(:organization, name: "Zeta Test Center"),
                         title: "Facilitator", start_date: 1.year.ago.to_date)

    visit edit_person_path(person, anchor: "affiliations")

    expect(page).to have_text("Zeta Test Center", wait: 10)
  end

  it "leaves a section collapsed when no fragment asks for it" do
    create(:comment, commentable: person, topic: "Facilitator affiliation",
                     body: "Confirmed by phone.", created_by: admin)

    visit edit_person_path(person)

    expect(page).to have_css("#comments-section")
    expect(page).to have_no_text("Confirmed by phone.")
  end
end
