require "rails_helper"

RSpec.describe "workshops/_show_body", type: :view do
  let(:user) { create(:user) }
  let(:workshop) { create(:workshop, created_by: user) }

  before do
    assign(:quotes, [])
    assign(:leader_spotlights, [])
  end

  context "when workshop has no Spanish fields" do
    before do
      render partial: "workshops/show_body",
             locals: { workshop: workshop.decorate }
    end

    it "shows Details tab instead of English" do
      expect(rendered).to include("Details")
      expect(rendered).not_to include("Español")
    end

    it "does not render the Spanish content tab" do
      expect(rendered).not_to have_css("#spanish-content")
    end
  end

  context "when workshop has title_spanish" do
    before do
      workshop.update!(title_spanish: "Taller de Arte")
      render partial: "workshops/show_body",
             locals: { workshop: workshop.decorate }
    end

    it "shows English and Español tabs" do
      expect(rendered).to include("English")
      expect(rendered).to include("Español")
    end

    it "renders the Spanish title in the Spanish tab" do
      expect(rendered).to have_css("#spanish-content h2", text: "Taller de Arte")
    end
  end

  context "when workshop has Spanish rich text content but no title_spanish" do
    before do
      workshop.update!(rhino_objective_spanish: "Un objetivo en español")
      render partial: "workshops/show_body",
             locals: { workshop: workshop.decorate }
    end

    it "shows English and Español tabs" do
      expect(rendered).to include("English")
      expect(rendered).to include("Español")
    end

    it "does not render a Spanish title heading" do
      expect(rendered).not_to have_css("#spanish-content h2")
    end
  end
end
