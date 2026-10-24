require "rails_helper"

RSpec.describe "Removing a staff tagging", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Alma", last_name: "Alphason") }
  let!(:tagging) { create(:staff_tagging, staff_taggable: person) }

  before { sign_in admin }

  it "deletes the tagging from its edit page" do
    visit edit_staff_tagging_path(tagging, return_to: "staff_taggings")

    accept_confirm { click_link "Remove tagging" }

    expect(page).to have_content("Staff tagging was successfully removed.")
    expect(StaffTagging.exists?(tagging.id)).to be(false)
  end
end
