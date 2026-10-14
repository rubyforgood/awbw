require "rails_helper"

RSpec.describe "Editing my profile details", type: :system, js: true do
  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }
  let!(:arts) { create(:sector, :published, name: "Arts") }
  let!(:health) { create(:sector, :published, name: "Health") }
  let(:age_type) { create(:category_type, :published, name: "AgeRange") }
  let!(:children) { create(:category, :published, category_type: age_type, name: "Children (0-12)") }
  let!(:teens) { create(:category, :published, category_type: age_type, name: "Teens (13-17)") }
  let!(:old_phone) { create(:contact_method, contactable: person, value: "555-0100") }

  before do
    create(:sectorable_item, sectorable: person, sector: arts)
    create(:categorizable_item, categorizable: person, category: children)
    sign_in user
  end

  it "saves every section from the page" do
    visit details_person_path(person)

    fill_in "First name", with: "Jordan"
    fill_in "Last name", with: "Rivera"
    fill_in "Pronouns", with: "they/them"
    fill_in "How to say your name", with: "JOR-dan"
    fill_in "Bio", with: "I teach art."
    find("label", text: "Remove", exact_text: true).click
    fill_in "Add another phone number", with: "555-0199"
    fill_in "Street address", with: "1 Main St"
    fill_in "City", with: "Los Angeles"
    fill_in "State", with: "CA"
    fill_in "Zip code", with: "90001"
    select "LA City", from: "Area"
    fill_in "LinkedIn", with: "https://linkedin.com/in/jordan"
    find("label", text: "Arts").click
    find("label[title='Make this my main sector']", match: :first) # stars render
    within(find("[data-primary-tag-target='chip']", text: "Health")) { find("label[title='Make this my main sector']").click }
    find("label", text: "Children (0-12)").click
    within(find("[data-primary-tag-target='chip']", text: "Teens (13-17)")) { find("label[title='Make this my main age range']").click }
    fill_in "Type", with: "LMFT"
    fill_in "License number", with: "12345"
    click_button "Save"

    expect(page).to have_current_path(person_path(person))
    person.reload
    expect(person).to have_attributes(first_name: "Jordan", last_name: "Rivera", pronouns: "they/them",
                                      pronunciation: "JOR-dan", bio: "I teach art.",
                                      linked_in_url: "https://linkedin.com/in/jordan")
    expect(person.contact_methods.map(&:value)).to eq([ "555-0199" ])
    expect(person.addresses.map { |a| [ a.street_address, a.city, a.state, a.zip_code, a.locality ] })
      .to eq([ [ "1 Main St", "Los Angeles", "CA", "90001", "LA City" ] ])
    expect(person.sectors).to contain_exactly(health)
    expect(person.primary_sector).to eq(health)
    expect(person.age_range_categorizable_items.map(&:category)).to contain_exactly(teens)
    expect(person.primary_age_groups).to eq([ teens ])
    expect(person.professional_licenses.map { |l| [ l.kind, l.number ] }).to eq([ [ "LMFT", "12345" ] ])
  end
end
