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

  def set_text_input(input, value)
    page.execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
      input, value
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
      f.find("input[name*='title']").value.include?("Facilitator")
    }
    start_input = facilitator_row.find("input[name*='start_date']")
    set_date_input(start_input, "2019-07-01")

    expect(facilitator).to have_text("Jul 2019", wait: 5)
  end

  it "updates Facilitator since when a title changes" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    # Renaming the only exact "Facilitator" to a variant drops it — facilitator
    # matching is exact and case-sensitive, so "Lead Facilitator" no longer counts.
    facilitator_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("input[name*='title']").value.strip == "Facilitator"
    }
    set_text_input(facilitator_row.find("input[name*='title']"), "Lead Facilitator")

    expect(facilitator).to have_text("—", wait: 5)
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

  it "removes an affiliation via the editor and recalculates" do
    # Persisted affiliations are now deleted from the affiliation editor (reached
    # via the row's gear); removing the Facilitator (Mar 2020) leaves Volunteer (Jun 2022).
    facilitator = person.affiliations.find_by!(title: "Facilitator")
    visit edit_affiliation_path(facilitator, return_to: "person", origin_id: person.id)

    accept_confirm { click_button "Delete" }

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']", wait: 10)
    expect(affiliated).to have_text("Jun 2022", wait: 5)
  end

  # The org form renders "Affiliated since" as merged, year-based periods
  # (AffiliationPeriods) rather than a single range; it must live-update in that
  # same format so the value doesn't jump on save.
  context "on the organization form" do
    let!(:org_person) { create(:person) }
    let!(:merged_org) { create(:organization) }

    before do
      create(:affiliation, person: org_person, organization: merged_org,
             title: "Facilitator", start_date: "2018-01-01", end_date: "2019-12-31")
      create(:affiliation, person: org_person, organization: merged_org,
             title: "Facilitator", start_date: "2022-01-01", end_date: nil)
    end

    it "live-updates the merged 'Affiliated since' periods" do
      visit_and_wait edit_organization_path(merged_org)

      affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
      expect(affiliated).to have_text("2018-2019, 2022")

      ongoing_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
        f.find("input[name*='start_date']").value == "2022-01-01"
      }
      set_date_input(ongoing_row.find("input[name*='start_date']"), "2021-05-01")

      expect(affiliated).to have_text("2018-2019, 2021", wait: 5)
    end
  end
end
