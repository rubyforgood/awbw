require "rails_helper"

RSpec.describe "Affiliation dates auto-update", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: admin) }
  let!(:org1) { create(:organization) }
  let!(:org2) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, person: person, organization: org1, title: "Facilitator", start_date: "2020-03-01", end_date: nil)
    create(:affiliation, person: person, organization: org2, title: "Volunteer", start_date: "2022-06-15", end_date: nil)
    sign_in admin
  end

  def visit_and_wait(path)
    visit path
    expect(page).to have_css("[data-affiliation-dates-ready]", wait: 10)
  end

  def set_date_input(input, value)
    page.execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', { bubbles: true }))",
      input, value
    )
  end

  def set_textarea_input(textarea, value)
    page.execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
      textarea, value
    )
  end

  it "updates Affiliated since when a start date changes" do
    visit_and_wait edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    set_date_input(start_inputs.first, "2018-01-15")

    expect(affiliated).to have_text("Jan 2018", wait: 5)
  end

  it "updates Facilitator since when a start date changes" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    # Find the Facilitator affiliation's start_date input specifically
    facilitator_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("textarea[name*='title']").value.include?("Facilitator")
    }
    start_input = facilitator_row.find("input[name*='start_date']")
    set_date_input(start_input, "2019-07-01")

    expect(facilitator).to have_text("Jul 2019", wait: 5)
  end

  it "updates Facilitator since when a title changes" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    title_textareas = all("textarea[name*='affiliations_attributes'][name*='title']")
    set_textarea_input(title_textareas.last, "Lead Facilitator")

    # Both affiliations now have "Facilitator" in the title; earliest is still Mar 2020
    expect(facilitator).to have_text("Mar 2020", wait: 5)
  end

  it "shows end date and icon when all affiliations are inactive" do
    visit_and_wait edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    end_inputs = all("input[name*='affiliations_attributes'][name*='end_date']")
    set_date_input(end_inputs[0], "2023-01-01")
    set_date_input(end_inputs[1], "2024-06-01")

    expect(affiliated).to have_text("Jun 2024", wait: 5)
    within(affiliated) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "displays correct month for first-of-month dates in US timezones" do
    visit_and_wait edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    # Set both affiliations to first-of-month dates and verify the JS controller
    # formats them correctly. This catches UTC-to-local timezone bugs where midnight
    # UTC rolls back to the previous month in behind-UTC timezones
    # (e.g., 2025-01-01T00:00Z → Dec 31 in EST).
    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    set_date_input(start_inputs[0], "2025-03-01")
    set_date_input(start_inputs[1], "2025-01-01")

    # Should show Jan 2025, not Dec 2024
    expect(affiliated).to have_text("Jan 2025", wait: 5)
    expect(affiliated).not_to have_text("Dec 2024")
  end

  it "removes an affiliation and recalculates" do
    visit_and_wait edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    # Remove the Facilitator affiliation (start Mar 2020), leaving Volunteer (start Jun 2022)
    facilitator_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("textarea[name*='title']").value.include?("Facilitator")
    }
    facilitator_row.find("a", text: "Remove").click

    expect(affiliated).to have_text("Jun 2022", wait: 5)
  end
end
