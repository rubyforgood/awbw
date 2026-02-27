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
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    set_date_input(start_inputs.first, "2018-01-15")

    expect { affiliated.text }.to eventually(include("Jan 2018"))
  end

  it "updates Facilitator since when a start date changes" do
    visit edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    set_date_input(start_inputs.first, "2019-07-01")

    expect { facilitator.text }.to eventually(include("Jul 2019"))
  end

  it "updates Facilitator since when a title changes" do
    visit edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    title_textareas = all("textarea[name*='affiliations_attributes'][name*='title']")
    set_textarea_input(title_textareas.last, "Lead Facilitator")

    # Both affiliations now have "Facilitator" in the title; earliest is still Mar 2020
    expect { facilitator.text }.to eventually(include("Mar 2020"))
  end

  it "shows end date and icon when all affiliations are inactive" do
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    end_inputs = all("input[name*='affiliations_attributes'][name*='end_date']")
    set_date_input(end_inputs[0], "2023-01-01")
    set_date_input(end_inputs[1], "2024-06-01")

    expect { affiliated.text }.to eventually(include("Jun 2024"))
    within(affiliated) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "removes an affiliation and recalculates" do
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    remove_links = all("a", text: "Remove")
    remove_links.first.click

    expect { affiliated.text }.to eventually(include("Jun 2022"))
  end
end
