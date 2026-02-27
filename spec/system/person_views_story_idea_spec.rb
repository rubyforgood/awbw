require "rails_helper"

RSpec.describe "Viewing a story idea", type: :system do
  let(:windows_type) { create(:windows_type, :combined) }
  let(:organization) { create(:organization, name: "Community Arts Project", windows_type_id: windows_type.id) }
  let(:workshop) { create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type) }

  describe "as the owner" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:story_idea) do
      create(:story_idea,
             created_by: user,
             organization: organization,
             workshop: workshop,
             windows_type: windows_type)
    end

    before do
      person # ensure person is created
      sign_in user
    end

    it "displays the organization as a clickable label" do
      visit story_idea_path(story_idea)

      expect(page).to have_link(organization.name, href: organization_path(organization))
    end

    it "displays the creator as a clickable label" do
      visit story_idea_path(story_idea)

      expect(page).to have_link(user.name, href: person_path(person))
    end
  end

  describe "as the owner without a person record" do
    let(:user) { create(:user) }
    let!(:story_idea) do
      create(:story_idea,
             created_by: user,
             organization: organization,
             workshop: workshop,
             windows_type: windows_type)
    end

    before { sign_in user }

    it "displays the creator as plain text" do
      visit story_idea_path(story_idea)

      expect(page).to have_text(user.full_name)
      expect(page).not_to have_link(user.full_name)
    end
  end

  describe "as an admin" do
    let(:admin) { create(:user, :admin) }
    let(:creator) { create(:user) }
    let(:creator_person) { create(:person, user: creator) }
    let!(:story_idea) do
      create(:story_idea,
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
      visit story_idea_path(story_idea)

      expect(page).to have_link(organization.name, href: organization_path(organization))
    end

    it "displays the creator as a clickable label" do
      visit story_idea_path(story_idea)

      expect(page).to have_link(creator.name, href: person_path(creator_person))
    end
  end
end
