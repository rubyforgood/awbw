require "rails_helper"

RSpec.describe "Staff taggings Clear filters", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:alpha) { create(:staff_tag, name: "Alpha Tag") }
  let!(:beta) { create(:staff_tag, name: "Beta Tag") }
  let!(:alpha_person) { create(:person, first_name: "Alma", last_name: "Alphason") }
  let!(:beta_person) { create(:person, first_name: "Bea", last_name: "Betason") }

  before do
    create(:staff_tagging, staff_tag: alpha, staff_taggable: alpha_person)
    create(:staff_tagging, staff_tag: beta, staff_taggable: beta_person)
    sign_in admin
  end

  it "clears the staff tag multiselect instead of selecting its first option" do
    visit staff_taggings_path(staff_tag_ids: [ beta.id ])

    within("turbo-frame#staff_taggings_results") do
      expect(page).to have_content("Bea Betason")
      expect(page).to have_no_content("Alma Alphason")
    end

    click_link "Clear filters"

    within("turbo-frame#staff_taggings_results") do
      expect(page).to have_content("Alma Alphason")
      expect(page).to have_content("Bea Betason")
    end
    expect(page.evaluate_script(%(Array.from(document.querySelector("select[name='staff_tag_ids[]']").selectedOptions).length))).to eq(0)
  end
end
