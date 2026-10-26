require "rails_helper"

RSpec.describe "people/profile_pieces/_sectors", type: :view do
  let(:person) { create(:person) }

  before do
    allow(view).to receive(:allowed_to?).and_return(false)
    create(:sectorable_item, sectorable: person, sector: create(:sector, :published, name: "Mental Health"), is_primary: true)
  end

  def add_sectors(count)
    count.times { |i| create(:sectorable_item, sectorable: person, sector: create(:sector, :published, name: "Sector #{i}")) }
  end

  def render_sectors(**locals)
    render partial: "people/profile_pieces/sectors", locals: { person: person, **locals }
    Capybara.string(rendered)
  end

  it "caps a long list to the column height behind a show-all toggle when filling height" do
    add_sectors(4)
    page = render_sectors(fill_height: true)
    expect(page).to have_css("input[type=checkbox]#sectors_show_all_person_#{person.id}", visible: :all)
    expect(page).to have_css("label[for=sectors_show_all_person_#{person.id}]", text: "Show all 5")
    expect(page).to have_link("Sector 3")
  end

  it "counts free-text other responses in the show-all total" do
    add_sectors(3)
    create(:other_response, owner: person, text: "Equine therapy")
    expect(render_sectors(fill_height: true)).to have_css("label", text: "Show all 5")
  end

  it "skips the toggle for three chips or fewer" do
    add_sectors(2)
    expect(render_sectors(fill_height: true)).not_to have_css("input[type=checkbox]", visible: :all)
  end

  it "lists every chip without a toggle when not filling height" do
    add_sectors(10)
    page = render_sectors
    expect(page).to have_link("Sector 9")
    expect(page).not_to have_css("input[type=checkbox]", visible: :all)
  end
end
