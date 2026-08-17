require "rails_helper"

RSpec.describe "Facilitator affiliation change warning", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:admin_person) { create(:person, user: admin) }
  let!(:facilitator_person) { create(:person) }
  let!(:volunteer_person) { create(:person) }
  let!(:organization) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, organization: organization, person: facilitator_person, title: "Facilitator", start_date: "2019-05-01", end_date: nil)
    create(:affiliation, organization: organization, person: volunteer_person, title: "Volunteer", start_date: "2021-09-15", end_date: nil)
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

  def row_for(title)
    all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("textarea[name*='title']").value.include?(title)
    }
  end

  it "warns and saves when a facilitator affiliation's date is edited and confirmed" do
    visit_and_wait edit_organization_path(organization, admin: true)

    start_input = row_for("Facilitator").find("input[name*='start_date']")
    set_date_input(start_input, "2017-02-01")

    accept_confirm(/status with AWBW/) do
      find("[type='submit']").click
    end

    expect(page).to have_current_path(organization_path(organization), wait: 10)
    expect(organization.affiliations.facilitators.first.reload.start_date).to eq(Date.new(2017, 2, 1))
  end

  it "cancels the save when the warning is dismissed" do
    visit_and_wait edit_organization_path(organization, admin: true)

    start_input = row_for("Facilitator").find("input[name*='start_date']")
    set_date_input(start_input, "2017-02-01")

    dismiss_confirm(/status with AWBW/) do
      find("[type='submit']").click
    end

    expect(page).to have_css("[type='submit']", wait: 5) # still on the edit form
    expect(organization.affiliations.facilitators.first.reload.start_date).to eq(Date.new(2019, 5, 1))
  end

  it "warns when a facilitator affiliation is removed from the editor" do
    facilitator = organization.affiliations.facilitators.first
    visit edit_affiliation_path(facilitator, return_to: "organization", origin_id: organization.id)

    accept_confirm(/status with AWBW/) do
      click_button "Delete"
    end

    expect(page).to have_css("[data-affiliation-dates-ready]", wait: 10)
    expect(organization.affiliations.facilitators).to be_empty
  end

  it "does not warn when only a non-facilitator affiliation is edited" do
    visit_and_wait edit_organization_path(organization, admin: true)

    start_input = row_for("Volunteer").find("input[name*='start_date']")
    set_date_input(start_input, "2020-01-01")

    find("[type='submit']").click

    expect(page).to have_current_path(organization_path(organization), wait: 10)
    expect(organization.affiliations.find_by(person: volunteer_person).reload.start_date).to eq(Date.new(2020, 1, 1))
  end
end
