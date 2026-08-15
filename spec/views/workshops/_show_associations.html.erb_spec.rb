require "rails_helper"

RSpec.describe "workshops/_show_associations", type: :view do
  let(:user) { create(:user) }
  let(:workshop) { create(:workshop, created_by: user) }

  before do
    assign(:workshop, workshop)
    assign(:workshop_variations, [])
    assign(:quotes, [])
    assign(:leader_spotlights, [])
    assign(:mentioners, {})
    assign(:mentionees, {})
  end

  describe "facilitator spotlights" do
    let(:author) { create(:person, first_name: "Rosalind", last_name: "Franklin") }
    let(:spotlight) { create(:resource, kind: "LeaderSpotlight", published: true, author: author) }

    before do
      assign(:leader_spotlights, [ spotlight ])
      allow(view).to receive(:allowed_to?).and_return(false)
    end

    it "credits the spotlight through the author's profile, not the raw association" do
      author.update!(display_name_preference: "first_name_last_initial")
      render partial: "workshops/show_associations", locals: { workshop: workshop.decorate }

      expect(rendered).to include("Rosalind F.")
      expect(rendered).not_to include("Rosalind Franklin")
    end

    it "renders Anonymous when the author's profile suppresses credits" do
      author.update!(anonymous_contributions: true)
      render partial: "workshops/show_associations", locals: { workshop: workshop.decorate }

      expect(rendered).to include("Anonymous")
      expect(rendered).not_to include("Rosalind")
    end
  end

  context "when user can manage WorkshopVariation" do
    before do
      allow(view).to receive(:allowed_to?).and_return(false)
      allow(view).to receive(:allowed_to?).with(:new?, WorkshopVariation).and_return(true)
      render partial: "workshops/show_associations", locals: { workshop: workshop.decorate }
    end

    it "displays the New variation button" do
      expect(rendered).to have_link("New variation", href: new_workshop_variation_path(from: "workshop_show", workshop_id: workshop.id))
    end
  end

  context "when user cannot manage WorkshopVariation" do
    before do
      allow(view).to receive(:allowed_to?).and_return(false)
      render partial: "workshops/show_associations", locals: { workshop: workshop.decorate }
    end

    it "does not display the New variation button" do
      expect(rendered).not_to have_link("New variation")
    end
  end
end
