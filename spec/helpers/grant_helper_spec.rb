require "rails_helper"

RSpec.describe GrantHelper, type: :helper do
  describe "#grant_funder_badge" do
    it "renders a person funder with the people-colored person icon and name" do
      person = create(:person, first_name: "Bob", last_name: "Barker")
      grant = create(:grant, funder: person)

      badge = helper.grant_funder_badge(grant)

      expect(badge).to include("fa-user")
      expect(badge).to include(DomainTheme.text_class_for(:people))
      expect(badge).to include("Bob Barker")
      expect(badge).not_to include("Person:")
    end

    it "renders an organization funder with the organizations-colored building icon and name" do
      organization = create(:organization, name: "Helping Hands")
      grant = create(:grant, funder: organization)

      badge = helper.grant_funder_badge(grant)

      expect(badge).to include("fa-building")
      expect(badge).to include(DomainTheme.text_class_for(:organizations))
      expect(badge).to include("Helping Hands")
      expect(badge).not_to include("Organization:")
    end
  end
end
