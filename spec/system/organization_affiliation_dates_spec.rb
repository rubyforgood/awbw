require "rails_helper"

RSpec.describe "Organization affiliation dates auto-update", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person1) { create(:person) }
  let!(:person2) { create(:person) }
  let!(:organization) { create(:organization) }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, organization: organization, person: person1, title: "Facilitator", start_date: "2019-05-01", end_date: nil)
    create(:affiliation, organization: organization, person: person2, title: "Volunteer", start_date: "2021-09-15", end_date: nil)
    sign_in admin
  end

  it "updates Affiliated since when a start date changes" do
    visit edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("May 2019")

    start_inputs = all("input[name*='affiliations_attributes'][name*='start_date']")
    start_inputs.first.fill_in with: "2017-02-01"

    expect { affiliated.text }.to eventually(include("Feb 2017"))
  end

  it "shows end date and icon when all affiliations are inactive" do
    visit edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")

    end_inputs = all("input[name*='affiliations_attributes'][name*='end_date']")
    end_inputs[0].fill_in with: "2023-03-01"
    end_inputs[1].fill_in with: "2024-08-01"

    expect { affiliated.text }.to eventually(include("Aug 2024"))
    within(affiliated) do
      expect(page).to have_css("i.fa-circle-xmark")
    end
  end

  it "removes an affiliation and recalculates" do
    visit edit_organization_path(organization, admin: true)

    affiliated = find("[data-affiliation-dates-target='affiliatedSince']")
    expect(affiliated).to have_text("May 2019")

    remove_links = all("a", text: "Remove")
    remove_links.first.click

    expect { affiliated.text }.to eventually(include("Sep 2021"))
  end
end
