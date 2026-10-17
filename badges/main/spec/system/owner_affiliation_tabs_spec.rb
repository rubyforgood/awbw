require "rails_helper"

RSpec.describe "Owner affiliation Active/Inactive tabs", type: :system do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, person: person, organization: create(:organization, name: "Currently Facilitating"),
                         title: "Facilitator", start_date: 2.years.ago.to_date)
    create(:affiliation, person: person, organization: create(:organization, name: "Long Since Ended"),
                         title: "Facilitator", start_date: 4.years.ago.to_date, end_date: 1.year.ago.to_date)
    allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
    sign_in owner_user
    visit edit_person_path(person)
  end

  it "shows only active affiliations until the Inactive tab is picked" do
    within("#affiliations") do
      expect(page).to have_text("Currently Facilitating")
      expect(page).to have_no_text("Long Since Ended")

      find("label", text: "Inactive").click

      expect(page).to have_text("Long Since Ended")
      expect(page).to have_no_text("Currently Facilitating")
    end
  end
end
