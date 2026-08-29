require "rails_helper"

RSpec.describe "Affiliation Active/Inactive tabs", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:person) { create(:person, user: admin) }
  let!(:current_org) { create(:organization, name: "Currently Facilitating") }
  let!(:ended_org) { create(:organization, name: "Long Since Ended") }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, person: person, organization: current_org,
                         title: "Facilitator", start_date: 2.years.ago.to_date)
    create(:affiliation, person: person, organization: ended_org, title: "Facilitator",
                         start_date: 4.years.ago.to_date, end_date: 1.year.ago.to_date)
    sign_in admin
    visit edit_person_path(person)
  end

  def row_for(name)
    find("[data-paginated-fields-target='item']", text: name, visible: :all)
  end

  it "shows only the active affiliation on the Active tab" do
    expect(row_for("Currently Facilitating")).to be_visible
    expect(row_for("Long Since Ended")).not_to be_visible
  end

  it "swaps to the ended one on the Inactive tab, and back" do
    find("label", text: "Inactive").click

    expect(row_for("Long Since Ended")).to be_visible
    expect(row_for("Currently Facilitating")).not_to be_visible

    find("label", text: "Active").click

    expect(row_for("Currently Facilitating")).to be_visible
    expect(row_for("Long Since Ended")).not_to be_visible
  end

  it "opens the affiliation editor's comments when the icon is clicked" do
    affiliation = person.affiliations.find_by(organization: current_org)
    affiliation.comments.create!(body: "Why this ended")
    visit edit_person_path(person)

    link = find(".fa-comment").find(:xpath, "..")
    expect(link[:href]).to end_with("#comments-section")
    expect(link[:target]).to eq("_blank")

    visit link[:href]

    expect(page).to have_css("#comments-section")
    # Comments read as text until "Edit comments" is clicked.
    expect(page).to have_text("Why this ended")
  end

  # The point of doing this client-side: a row you end mid-edit must not vanish
  # from under you. It restyles in place and only changes tab after a save.
  it "keeps a row you end on the Active tab, restyled" do
    row = row_for("Currently Facilitating")
    end_date = row.find("input[data-inactive-toggle-target~='endDate']", visible: :all)

    page.execute_script(
      "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('change', { bubbles: true }))",
      end_date, 1.month.ago.to_date.strftime("%Y-%m-%d")
    )

    expect(row).to be_visible
    expect(row).to have_css(".aff-ended")
  end
end
