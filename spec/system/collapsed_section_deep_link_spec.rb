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

  it "reopens the section on every same-page anchor click, not just the first" do
    workshop = create(:workshop)
    age_type = create(:category_type, :published, name: "AgeRange")
    create(:category, :published, category_type: age_type, name: "Teens (13-17)")
    create(:comment, commentable: workshop, body: "[AGE_RANGE_DATA] Teens", created_by: admin)

    visit edit_workshop_path(workshop)
    click_button "Tags"

    chip = first("a[href='#comments-section']")
    chip.click
    expect(page).to have_css("#comments-section[open]")

    # Collapsing by hand leaves the fragment in the URL, so the next click fires
    # no hashchange — the click handler is what reopens it.
    find("#comments-section > summary").click
    expect(page).to have_no_css("#comments-section[open]")

    first("a[href='#comments-section']").click
    expect(page).to have_css("#comments-section[open]")
  end

  it "leaves a section collapsed when no fragment asks for it" do
    create(:comment, commentable: person, topic: "Facilitator affiliation",
                     body: "Confirmed by phone.", created_by: admin)

    visit edit_person_path(person)

    expect(page).to have_css("#comments-section")
    expect(page).to have_no_text("Confirmed by phone.")
  end
end
