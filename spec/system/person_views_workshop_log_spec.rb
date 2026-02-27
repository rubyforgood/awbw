require "rails_helper"

RSpec.describe "Viewing a workshop log", type: :system do
  let(:windows_type) { create(:windows_type, :combined) }
  let(:organization) { create(:organization, name: "Community Arts Project", windows_type_id: windows_type.id) }
  let(:workshop) { create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type) }

  describe "as a regular user" do
    let(:user) { create(:user) }
    let(:person) { create(:person, user: user) }
    let!(:affiliation) { create(:affiliation, person: person, organization: organization) }
    let!(:workshop_log) do
      create(:workshop_log,
             created_by: user,
             organization: organization,
             owner: workshop,
             workshop: workshop,
             windows_type: windows_type,
             date: 1.day.ago)
    end

    before { sign_in user }

    it "displays the organization as a clickable label" do
      visit workshop_log_path(workshop_log)

      expect(page).to have_link("Community Arts Project", href: organization_path(organization))
    end

    it "displays the creator as a clickable label" do
      visit workshop_log_path(workshop_log)

      expect(page).to have_link(user.name, href: person_path(person))
    end
  end

  describe "as a user without a person record" do
    let(:user) { create(:user) }
    let!(:workshop_log) do
      create(:workshop_log,
             created_by: user,
             organization: organization,
             owner: workshop,
             workshop: workshop,
             windows_type: windows_type,
             date: 1.day.ago)
    end

    before { sign_in user }

    it "displays the creator as plain text" do
      visit workshop_log_path(workshop_log)

      expect(page).to have_text(user.name)
      expect(page).not_to have_link(user.name)
    end
  end

  describe "as an admin" do
    let(:admin) { create(:user, :admin) }
    let(:person) { create(:person, user: admin) }
    let!(:affiliation) { create(:affiliation, person: person, organization: organization) }
    let!(:workshop_log) do
      create(:workshop_log,
             created_by: admin,
             organization: organization,
             owner: workshop,
             workshop: workshop,
             windows_type: windows_type,
             date: 1.day.ago)
    end

    before { sign_in admin }

    it "displays the organization as a clickable label" do
      visit workshop_log_path(workshop_log)

      expect(page).to have_link("Community Arts Project", href: organization_path(organization))
    end

    it "displays the creator as a clickable label" do
      visit workshop_log_path(workshop_log)

      expect(page).to have_link(admin.name, href: person_path(person))
    end
  end
end
