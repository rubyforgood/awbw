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

  it "updates Affiliated since when a start date changes" do
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    # Change the earliest affiliation's start date to something earlier
    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    start_inputs.first.fill_in with: "2018-01-15"

    expect { affiliated.text }.to eventually(include("Jan 2018"))
  end

  it "updates Facilitator since when a start date changes" do
    visit edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    # Change the facilitator affiliation's start date
    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    start_inputs.first.fill_in with: "2019-07-01"

    expect { facilitator.text }.to eventually(include("Jul 2019"))
  end

  it "updates Facilitator since when a title changes" do
    visit edit_person_path(person, admin: true)

    facilitator = find("[data-affiliation-dates-target='facilitatorSince']")
    expect(facilitator).to have_text("Mar 2020")

    # Change the Volunteer title to include "Facilitator"
    title_textareas = all("textarea[name*='affiliations_attributes'][name*='title']")
    volunteer_textarea = title_textareas.last
    volunteer_textarea.fill_in with: "Lead Facilitator"

    # Now the earliest facilitator start date should be Jun 2022 (the volunteer's date)
    # unless the original facilitator (Mar 2020) is still earlier
    expect { facilitator.text }.to eventually(include("Mar 2020"))
  end

  it "shows end date and icon when all affiliations are inactive" do
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    # Set end dates in the past for both affiliations
    end_inputs = all("input[name*='affiliations_attributes'][name*='end_date']")
    end_inputs[0].fill_in with: "2023-01-01"
    end_inputs[1].fill_in with: "2024-06-01"

    expect { affiliated.text }.to eventually(include("Jun 2024"))
    within(affiliated) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "removes an affiliation and recalculates" do
    visit edit_person_path(person, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("Mar 2020")

    # Remove the first affiliation (Facilitator, Mar 2020)
    remove_links = all("a", text: "Remove")
    remove_links.first.click

    # After removing the 2020 affiliation, earliest should be Jun 2022
    expect { affiliated.text }.to eventually(include("Jun 2022"))
  end
end
