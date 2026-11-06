require "rails_helper"

RSpec.describe "Organization workshops and ideas", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:windows_type) { create(:windows_type, :adult) }
  let(:organization) { create(:organization, name: "Community Arts Center") }
  let(:affiliated_person) { create(:person, first_name: "Jane", last_name: "Artist") }

  before do
    driven_by(:selenium_chrome_headless)
    create(:affiliation, organization: organization, person: affiliated_person)
  end

  scenario "Organization profile displays directly associated workshops and ideas" do
    sign_in(admin)

    direct_workshop = create(:workshop, :published,
                             title: "Direct Pottery Workshop",
                             organization: organization,
                             windows_type: windows_type)
    direct_idea = create(:workshop_idea,
                         title: "Direct Clay Idea",
                         organization: organization,
                         windows_type: windows_type,
                         created_by: admin)

    visit organization_path(organization)

    expect(page).to have_content("Workshops authored")
    expect(page).to have_content(direct_workshop.title)
    expect(page).to have_content("Workshop ideas")
    expect(page).to have_content(direct_idea.title)
  end

  scenario "Organization profile displays workshops and ideas authored by affiliated people" do
    sign_in(admin)

    affiliated_workshop = create(:workshop, :published,
                                 title: "Affiliated Painting Workshop",
                                 author: affiliated_person,
                                 organization: nil,
                                 windows_type: windows_type)
    affiliated_idea = create(:workshop_idea,
                             title: "Affiliated Canvas Idea",
                             author: affiliated_person,
                             organization: nil,
                             windows_type: windows_type,
                             created_by: admin)

    visit organization_path(organization)

    expect(page).to have_content(affiliated_workshop.title)
    expect(page).to have_content(affiliated_idea.title)
  end

  scenario "Avoids duplicates when a workshop is both directly and indirectly associated" do
    sign_in(admin)

    create(:workshop, :published,
           title: "Dual Linked Workshop",
           author: affiliated_person,
           organization: organization,
           windows_type: windows_type)

    visit organization_path(organization)

    expect(page.all("a", text: "Dual Linked Workshop").count).to eq(1)
  end
end
