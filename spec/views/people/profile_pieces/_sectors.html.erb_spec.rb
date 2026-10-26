require "rails_helper"

RSpec.describe "people/profile_pieces/_sectors", type: :view do
  let(:person) { create(:person) }

  before { allow(view).to receive(:allowed_to?).and_return(false) }

  def add_sectors(count, primary_name: nil)
    create(:sectorable_item, sectorable: person, sector: create(:sector, :published, name: primary_name), is_primary: true) if primary_name
    count.times { |i| create(:sectorable_item, sectorable: person, sector: create(:sector, :published, name: "Sector #{i.to_s.rjust(2, "0")}")) }
  end

  def render_sectors
    render partial: "people/profile_pieces/sectors", locals: { person: person }
    Capybara.string(rendered)
  end

  it "shows the primary and two more, folding the rest behind a toggle" do
    add_sectors(5, primary_name: "Mental Health")
    page = render_sectors
    visible = page.find("div.flex-wrap", match: :first)
    expect(visible).to have_link("Mental Health")
    expect(visible).to have_link("Sector 00")
    expect(visible).to have_link("Sector 01")
    expect(visible).not_to have_link("Sector 02")
    expect(page).to have_css("details summary", text: "Show 3 more")
    expect(page.find("details")).to have_link("Sector 04", visible: :hidden)
  end

  it "shows every chip without a toggle when only one would be folded" do
    add_sectors(3, primary_name: "Mental Health")
    page = render_sectors
    expect(page).to have_link("Sector 02")
    expect(page).not_to have_css("details")
  end

  it "folds free-text other responses behind the toggle too" do
    add_sectors(3, primary_name: "Mental Health")
    create(:other_response, owner: person, text: "Equine therapy")
    page = render_sectors
    expect(page).to have_css("details summary", text: "Show 2 more")
    expect(page.find("details")).to have_text(:all, "Equine therapy")
  end
end
