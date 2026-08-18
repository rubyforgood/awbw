require "rails_helper"

RSpec.describe "Organization program status live update", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person) }
  # A stored status that contradicts the affiliations, to prove it never feeds the
  # chip: the org reads Active purely because a facilitator affiliation is active.
  let!(:stored_status) { create(:organization_status, name: "Pending") }
  let!(:organization) { create(:organization, organization_status: stored_status) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, person: person, organization: organization,
           title: "Facilitator", start_date: "2020-03-01", end_date: nil)
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

  def status_chip
    find("[data-affiliation-dates-target='programStatus']")
  end

  it "flips Active to Formerly active when the facilitator's end date moves to the past" do
    visit_and_wait edit_organization_path(organization)
    expect(status_chip).to have_text("Active")

    end_input = find("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields input[name*='end_date']")
    set_date_input(end_input, "2020-06-01")

    expect(status_chip).to have_text("Formerly active", wait: 5)
  end

  it "drops to Never active when the only facilitator row is retitled to a non-facilitator" do
    visit_and_wait edit_organization_path(organization)
    expect(status_chip).to have_text("Active")

    # Persisted rows can't be removed inline (that's the gear's affiliation editor),
    # so retitle the sole facilitator: the live chip counts zero facilitators.
    title_input = find("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields input[name*='title']")
    title_input.set("Volunteer")

    expect(status_chip).to have_text("Never active", wait: 5)
  end
end
