require "rails_helper"

RSpec.describe "People can submit a workshop variation idea", type: :system do
  def fill_in_rhino_editor(content)
    page.execute_script(
      "document.getElementById('workshop_variation_idea_rhino_body').value = arguments[0]",
      content
    )
  end

  def select_workshop_via_tom_select(workshop_title)
    find(".ts-control").click
    find(".ts-control input").set(workshop_title)
    within(".ts-dropdown") do
      find(".option", text: workshop_title).click
    end
  end

  def select_organization(organization)
    find("#workshop_variation_idea_organization_id option[value='#{organization.id}']").select_option
  end

  def open_mobile_new_menu
    find("button[data-dropdown-payload-param*='mobile-menu']").click
    within("#mobile-menu") do
      find("button", text: "New").click
    end
  end

  def fill_in_variation_idea_form(workshop_title:, windows_type_short_name:, organization: nil)
    fill_in "Variation name", with: "My Healing Art Variation"
    select_workshop_via_tom_select(workshop_title)
    select windows_type_short_name, from: "workshop_variation_idea_windows_type_id"
    select_organization(organization) if organization
    fill_in_rhino_editor("<p>This is my variation idea with details about adaptation.</p>")
    select "I would like my full name published with the story",
           from: "workshop_variation_idea_author_credit_preference"
    check "workshop_variation_idea_permission_given"
  end

  describe "Regular user submits from navbar" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:windows_type) { create(:windows_type, :adult) }
    let!(:workshop) { create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type) }
    let!(:organization) { create(:organization, name: "Test Agency") }

    before do
      create(:affiliation, person: person, organization: organization)
      create(:affiliation, person: person, organization: create(:organization, name: "Second Agency"))
      sign_in user
      visit root_path
    end

    it "navigates via mobile navbar, fills form, and submits successfully" do
      open_mobile_new_menu
      click_link "New workshop variation idea"

      expect(page).to have_content("New workshop variation idea")

      fill_in_variation_idea_form(
        workshop_title: "Healing Through Art",
        windows_type_short_name: "Adult",
        organization: organization
      )

      click_button "Submit"

      expect(page).to have_content("Workshop variation idea was successfully created.")
      expect(page).to have_content("My Healing Art Variation")
    end
  end

  describe "Regular user submits from workshop show page" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:windows_type) { create(:windows_type, :adult) }
    let!(:workshop) { create(:workshop, :published, title: "Creative Expression", windows_type: windows_type) }
    let!(:organization) { create(:organization, name: "Art Center") }

    before do
      create(:affiliation, person: person, organization: organization)
      create(:affiliation, person: person, organization: create(:organization, name: "Backup Agency"))
      sign_in user
      visit workshop_path(workshop)
    end

    it "clicks 'New variation idea' from workshop show, fills form, and redirects back" do
      click_link "New variation idea", wait: 10

      expect(page).to have_content("New workshop variation idea")

      fill_in_variation_idea_form(
        workshop_title: "Creative Expression",
        windows_type_short_name: "Adult",
        organization: organization
      )

      click_button "Submit"

      expect(page).to have_content("Workshop variation idea was successfully created.")
      expect(page).to have_content(workshop.title)
    end
  end

  describe "Admin submits from navbar" do
    let(:admin) { create(:user, :admin) }
    let(:person) { create(:person, user: admin) }
    let!(:windows_type) { create(:windows_type, :adult) }
    let!(:workshop) { create(:workshop, :published, title: "Advanced Art Therapy", windows_type: windows_type) }
    let!(:organization) { create(:organization, name: "Admin Org") }

    before do
      create(:affiliation, person: person, organization: organization)
      create(:affiliation, person: person, organization: create(:organization, name: "Admin Org 2"))
      sign_in admin
      visit root_path
    end

    it "navigates via mobile navbar, fills form, and redirects to show page" do
      open_mobile_new_menu
      click_link "New workshop variation idea"

      expect(page).to have_content("New workshop variation idea")

      fill_in_variation_idea_form(
        workshop_title: "Advanced Art Therapy",
        windows_type_short_name: "Adult",
        organization: organization
      )

      click_button "Submit"

      expect(page).to have_content("Workshop variation idea was successfully created.")
      expect(page).to have_content("My Healing Art Variation")
    end
  end

  describe "Admin submits from workshop show page" do
    let(:admin) { create(:user, :admin) }
    let(:person) { create(:person, user: admin) }
    let!(:windows_type) { create(:windows_type, :adult) }
    let!(:workshop) { create(:workshop, :published, title: "Mindful Drawing", windows_type: windows_type) }
    let!(:organization) { create(:organization, name: "Mindful Agency") }

    before do
      create(:affiliation, person: person, organization: organization)
      create(:affiliation, person: person, organization: create(:organization, name: "Mindful Agency 2"))
      sign_in admin
      visit workshop_path(workshop)
    end

    it "clicks 'New variation idea' from workshop show and redirects back to workshop" do
      click_link "New variation idea", wait: 10

      expect(page).to have_content("New workshop variation idea")

      fill_in_variation_idea_form(
        workshop_title: "Mindful Drawing",
        windows_type_short_name: "Adult",
        organization: organization
      )

      click_button "Submit"

      expect(page).to have_content("Workshop variation idea was successfully created.")
      expect(page).to have_content(workshop.title)
    end
  end

  describe "Organization field based on affiliations" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:windows_type) { create(:windows_type, :adult) }
    let!(:workshop) { create(:workshop, :published, title: "Org Test Workshop", windows_type: windows_type) }
    let!(:organization) { create(:organization, name: "Primary Agency") }

    context "when user has one affiliation" do
      before do
        create(:affiliation, person: person, organization: organization)
        sign_in user
        visit new_workshop_variation_idea_path
      end

      it "auto-sets organization without showing the dropdown" do
        expect(page).not_to have_select("workshop_variation_idea_organization_id")

        fill_in "Variation name", with: "Single Org Variation"
        select_workshop_via_tom_select("Org Test Workshop")
        select "Adult", from: "workshop_variation_idea_windows_type_id"
        fill_in_rhino_editor("<p>Variation for a single-org user.</p>")
        select "I would like my full name published with the story",
               from: "workshop_variation_idea_author_credit_preference"
        check "workshop_variation_idea_permission_given"

        click_button "Submit"

        expect(page).to have_content("Workshop variation idea was successfully created.")
        expect(WorkshopVariationIdea.last.organization).to eq(organization)
      end
    end

    context "when user has multiple affiliations" do
      let!(:second_organization) { create(:organization, name: "Second Agency") }

      before do
        create(:affiliation, person: person, organization: organization)
        create(:affiliation, person: person, organization: second_organization)
        sign_in user
        visit new_workshop_variation_idea_path
      end

      it "requires selecting an organization from the dropdown" do
        expect(page).to have_select("workshop_variation_idea_organization_id")

        fill_in "Variation name", with: "Multi Org Variation"
        select_workshop_via_tom_select("Org Test Workshop")
        select "Adult", from: "workshop_variation_idea_windows_type_id"
        select_organization(organization)
        fill_in_rhino_editor("<p>Variation for a multi-org user.</p>")
        select "I would like my full name published with the story",
               from: "workshop_variation_idea_author_credit_preference"
        check "workshop_variation_idea_permission_given"

        click_button "Submit"

        expect(page).to have_content("Workshop variation idea was successfully created.")
        expect(WorkshopVariationIdea.last.organization).to eq(organization)
      end
    end
  end

  describe "Form validation errors" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }

    before do
      create(:affiliation, person: person, organization: create(:organization))
      create(:affiliation, person: person, organization: create(:organization))
      sign_in user
      visit new_workshop_variation_idea_path
    end

    it "shows validation errors when required fields are missing" do
      click_button "Submit"

      expect(page).to have_content("can't be blank")
    end
  end
end
