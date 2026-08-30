require "rails_helper"

RSpec.describe "Affiliation status badges", type: :system do
  # Requests render in the signed-in user's zone (ApplicationController
  # #set_time_zone_from_user), so pin it to the spec process's own zone —
  # otherwise "starts today" straddles a date boundary depending on the hour.
  let(:admin) { create(:user, :admin, time_zone: Time.zone.name) }
  let!(:person) { create(:person, user: admin) }
  let!(:org) { create(:organization, name: "Zeta Test Center") }

  before do
    driven_by(:selenium_chrome_headless)
    sign_in admin
  end

  # Read from classList rather than Capybara visibility: `hidden` only hides once
  # the Tailwind build is loaded, and the fast test path skips that build.
  def badge_hidden?(row, target)
    page.evaluate_script(
      "arguments[0].querySelector(\"[data-inactive-toggle-target='#{target}']\").classList.contains('hidden')",
      row.native
    )
  end

  # The controller reacts to `change` on the start-date input; set the value and
  # fire it, rather than driving Chrome's segmented date widget by keystroke.
  def set_start_date(row, value)
    page.execute_script(<<~JS, row.find("input[data-inactive-toggle-target~='startDate']").native, value.to_s)
      arguments[0].value = arguments[1];
      arguments[0].dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end

  it "adds and removes the badges live as the start date is edited" do
    create(:affiliation, person: person, organization: org, title: "Counselor",
                         start_date: 1.year.ago.to_date, end_date: nil)

    visit edit_person_path(person)
    row = find(".nested-fields", wait: 10)

    # Active as rendered — neither badge showing.
    expect(badge_hidden?(row, "inactiveBadge")).to be true
    expect(badge_hidden?(row, "upcomingBadge")).to be true

    set_start_date(row, 1.month.from_now.to_date.iso8601)
    expect(page).to have_css("[data-inactive-toggle-target='upcomingBadge']:not(.hidden)", wait: 5)
    expect(badge_hidden?(row, "inactiveBadge")).to be false

    # Back to a started date: both badges go away again.
    set_start_date(row, 1.year.ago.to_date.iso8601)
    expect(page).to have_css("[data-inactive-toggle-target='upcomingBadge'].hidden", wait: 5)
    expect(badge_hidden?(row, "inactiveBadge")).to be true
  end
end
