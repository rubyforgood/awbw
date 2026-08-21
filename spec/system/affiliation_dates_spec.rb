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

  def facilitator_row
    all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("input[name*='title']").value.strip == "Facilitator"
    }
  end

  it "updates Facilitator since when a start date changes" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    set_date_input(facilitator_row.find("input[name*='start_date']"), "2019-07-01")

    expect(facilitator).to have_text("Jul 2019", wait: 5)
  end

  it "updates Facilitator since when a title changes" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    # Renaming the only exact "Facilitator" to a variant drops it — facilitator
    # matching is exact and case-sensitive, so "Lead Facilitator" no longer counts.
    set_text_input(facilitator_row.find("input[name*='title']"), "Lead Facilitator")

    expect(facilitator).to have_text("—", wait: 5)
  end

  it "shows end date and icon when the facilitator affiliation is inactive" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")

    set_date_input(facilitator_row.find("input[name*='end_date']"), "2023-01-01")

    expect(facilitator).to have_text("Jan 2023", wait: 5)
    within(facilitator) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "displays correct month for first-of-month dates in US timezones" do
    visit_and_wait edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")

    # A first-of-month date must format to that month, not roll back a day. This
    # catches UTC-to-local timezone bugs where midnight UTC lands on the previous
    # month in behind-UTC timezones (e.g., 2025-01-01T00:00Z → Dec 31 in EST).
    set_date_input(facilitator_row.find("input[name*='start_date']"), "2025-01-01")

    expect(facilitator).to have_text("Jan 2025", wait: 5)
    expect(facilitator).not_to have_text("Dec 2024")
  end

  it "surfaces the affiliation start as a grey note when it differs from the facilitator start" do
    # Facilitator (Mar 2020) gone; the remaining Volunteer (Jun 2022) now surfaces
    # as the grey "Affiliated since" note beside an empty Facilitator since.
    facilitator = person.affiliations.find_by!(title: "Facilitator")
    visit edit_affiliation_path(facilitator, return_to: "person", origin_id: person.id)

    accept_confirm { click_button "Delete" }

    expect(page).to have_text("Affiliated since Jun 2022", wait: 10)
  end

  # "Facilitators since" on the org form is a merged-period value at month
  # precision, so it must live-update in that format — not an earliest→latest range.
  context "on the organization form" do
    let!(:org_person) { create(:person) }
    let!(:merged_org) { create(:organization) }

    before do
      create(:affiliation, person: org_person, organization: merged_org,
             title: "Facilitator", start_date: "2018-01-01", end_date: "2019-12-31")
      create(:affiliation, person: org_person, organization: merged_org,
             title: "Facilitator", start_date: "2022-01-01", end_date: nil)
    end

    it "live-updates 'Facilitators since' as month-precision periods" do
      visit_and_wait edit_organization_path(merged_org)

      program = find("[data-affiliation-dates-target='facilitatorSince']")
      expect(program).to have_text("Jan 2018 – Dec 2019, Jan 2022")

      ongoing_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
        f.find("input[name*='start_date']").value == "2022-01-01"
      }
      set_date_input(ongoing_row.find("input[name*='start_date']"), "2021-05-01")

      expect(program).to have_text("Jan 2018 – Dec 2019, May 2021", wait: 5)
    end
  end
end
