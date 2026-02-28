require "rails_helper"

RSpec.describe "Organization affiliation dates auto-update", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:admin_person) { create(:person, user: admin) }
  let!(:person1) { create(:person) }
  let!(:person2) { create(:person) }
  let!(:organization) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, organization: organization, person: person1, title: "Facilitator", start_date: "2019-05-01", end_date: nil)
    create(:affiliation, organization: organization, person: person2, title: "Volunteer", start_date: "2021-09-15", end_date: nil)
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

  it "updates Affiliated since when a start date changes" do
    visit_and_wait edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("May 2019")

    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    set_date_input(start_inputs.first, "2017-02-01")

    expect(affiliated).to have_text("Feb 2017", wait: 5)
  end

  it "shows end date and icon when all affiliations are inactive" do
    visit_and_wait edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    end_inputs = all("input[name*='affiliations_attributes'][name*='end_date']")
    set_date_input(end_inputs[0], "2023-03-01")
    set_date_input(end_inputs[1], "2024-08-01")

    expect(affiliated).to have_text("Aug 2024", wait: 5)
    within(affiliated) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "removes an affiliation and recalculates" do
    visit_and_wait edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("May 2019")

    # Remove the Facilitator affiliation (start May 2019), leaving Volunteer (start Sep 2021)
    facilitator_row = all("[data-affiliation-dates-target='affiliationsContainer'] .nested-fields").find { |f|
      f.find("textarea[name*='title']").value.include?("Facilitator")
    }
    facilitator_row.find("a", text: "Remove").click

    expect(affiliated).to have_text("Sep 2021", wait: 5)
  end
end
