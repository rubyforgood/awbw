require "rails_helper"

RSpec.describe "Organization program status live update", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person) }
  let!(:pending_status) { create(:organization_status, name: "Pending") }
  let!(:organization) { create(:organization, organization_status: pending_status) }

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

  it "falls back to the stored status when the only facilitator is removed" do
    visit_and_wait edit_organization_path(organization)
    expect(status_chip).to have_text("Active")

    row = find("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields")
    row.find("a", text: "Remove").click

    expect(status_chip).to have_text("Never active", wait: 5)
  end
end
