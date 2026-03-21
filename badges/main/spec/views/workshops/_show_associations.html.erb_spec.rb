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
