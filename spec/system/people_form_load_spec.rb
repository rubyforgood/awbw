require "rails_helper"

RSpec.describe "People form loads", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, first_name: "Jane", last_name: "Doe", user: admin) }

  before { sign_in admin }

  scenario "new person page loads" do
    visit new_person_path

    expect(page).to have_content("New person")
  end

  scenario "edit person page loads" do
    visit edit_person_path(person)

    # the action is the eyebrow now (CSS-uppercased, so match loosely) and the
    # heading is just the name
    expect(page).to have_content(/edit person/i)
    expect(page).to have_content("Jane Doe")
  end
end
