require "rails_helper"

RSpec.describe "Person primary sector and age range stars", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let!(:health) { create(:sector, :published, name: "Healthcare") }
  let!(:education) { create(:sector, :published, name: "Education") }
  let(:person) { create(:person) }

  before { sign_in admin }

  def sector_stars
    all("input[type=checkbox][name$='[is_primary]'][name*='sectorable_items_attributes']", visible: :all)
  end

  def star_for(name)
    find(".nested-fields", text: name).find("input[type=checkbox][name$='[is_primary]']", visible: :all)
  end

  it "moves the star to a remaining sector when the starred one is removed" do
    person.sectorable_items.create!(sector: health, is_primary: true)
    person.sectorable_items.create!(sector: education, is_primary: false)

    visit edit_person_path(person)
    find(".nested-fields", text: "Healthcare").click_link("✖")

    expect(star_for("Education")).to be_checked
  end

  it "doesn't star anything when an unstarred sector is removed" do
    person.sectorable_items.create!(sector: health, is_primary: false)
    person.sectorable_items.create!(sector: education, is_primary: false)

    visit edit_person_path(person)
    find(".nested-fields", text: "Healthcare").click_link("✖")

    expect(star_for("Education")).not_to be_checked
  end

  it "saves with no primary once the star is cleared" do
    person.sectorable_items.create!(sector: health, is_primary: true)

    visit edit_person_path(person)
    find(".nested-fields", text: "Healthcare").find("label[title='Mark as primary sector']").click
    expect(star_for("Healthcare")).not_to be_checked

    click_button "Save changes"

    expect(page).to have_current_path(person_path(person), wait: 20)
    expect(person.reload.primary_sector).to be_nil
    expect(person.sectors).to contain_exactly(health)
  end

  it "stars a newly added sector when none of the others is starred" do
    person.sectorable_items.create!(sector: health, is_primary: false)
    person.sectorable_items.create!(sector: education, is_primary: false)

    visit edit_person_path(person)
    click_link "➕ Add Sector"

    expect(sector_stars.size).to eq(3)
    expect(sector_stars.map(&:checked?)).to eq([ false, false, true ])
  end

  it "keeps the existing star when a sector is added" do
    person.sectorable_items.create!(sector: health, is_primary: true)

    visit edit_person_path(person)
    click_link "➕ Add Sector"

    expect(sector_stars.map(&:checked?)).to eq([ true, false ])
  end

  it "stars the sector added to a person with none" do
    visit edit_person_path(person)

    click_link "➕ Add Sector"

    expect(sector_stars.size).to eq(1)
    expect(sector_stars.first).to be_checked
  end
end
