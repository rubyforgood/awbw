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

  it "stars the sector left when the other is removed" do
    person.sectorable_items.create!(sector: health, is_primary: false)
    person.sectorable_items.create!(sector: education, is_primary: false)

    visit edit_person_path(person)
    expect(sector_stars.none?(&:checked?)).to be(true)

    find(".nested-fields", text: "Healthcare").click_link("✖")

    expect(find(".nested-fields", text: "Education").find("input[type=checkbox][name$='[is_primary]']", visible: :all)).to be_checked
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
