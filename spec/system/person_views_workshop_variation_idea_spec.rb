require "rails_helper"

RSpec.describe "Viewing a workshop variation idea", type: :system do
  let(:windows_type) { create(:windows_type, :combined) }
  let(:organization) { create(:organization, name: "Community Arts Project", windows_type_id: windows_type.id) }
  let(:workshop) { create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type) }

  describe "as the owner" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:idea) do
      create(:workshop_variation_idea,
             created_by: user,
             organization: organization,
             workshop: workshop,
             windows_type: windows_type)
    end

    before do
      person # ensure person is created
      sign_in user
    end

    it "displays the organization as plain text (non-admin)" do
      visit workshop_variation_idea_path(idea)

      expect(page).to have_text(organization.name)
      expect(page).not_to have_link(organization.name)
    end

    it "displays the creator as a clickable label" do
      visit workshop_variation_idea_path(idea)

      expect(page).to have_link(user.name, href: person_path(person))
    end
  end

  describe "as the owner without a person record" do
    let(:user) { create(:user) }
    let!(:idea) do
      create(:workshop_variation_idea,
             created_by: user,
             organization: organization,
             workshop: workshop,
             windows_type: windows_type)
    end

    before { sign_in user }

    it "displays the creator as plain text" do
      visit workshop_variation_idea_path(idea)

      expect(page).to have_text(user.name)
      expect(page).not_to have_link(user.name)
    end
  end

  describe "as an admin" do
    let(:admin) { create(:user, :admin) }
    let(:creator) { create(:user) }
    let(:creator_person) { create(:person, user: creator) }
    let!(:idea) do
      create(:workshop_variation_idea,
             created_by: creator,
             organization: organization,
             workshop: workshop,
             windows_type: windows_type)
    end

    before do
      creator_person # ensure person is created
      sign_in admin
    end

    it "displays the organization as a clickable label" do
      visit workshop_variation_idea_path(idea)

      expect(page).to have_link(organization.name, href: organization_path(organization))
    end

    it "displays the creator as a clickable label" do
      visit workshop_variation_idea_path(idea)

      expect(page).to have_link(creator.name, href: person_path(creator_person))
    end
  end
end
