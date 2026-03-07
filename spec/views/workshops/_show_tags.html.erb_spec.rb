require "rails_helper"

RSpec.describe "workshops/_show_tags", type: :view do
  let(:user) { create(:user) }
  let(:workshop) { create(:workshop, created_by: user) }
  let(:type) { create(:category_type, :published, name: "Theme") }
  let(:category) { create(:category, :published, name: "Resilience", category_type: type) }
  let(:sector) { create(:sector, :published, name: "Education") }

  before do
    workshop.categories << category
    workshop.sectors << sector
  end

  context "when spanish is false" do
    before do
      render partial: "workshops/show_tags",
             locals: { workshop: workshop, spanish: false }
    end

    it "shows English tag labels" do
      expect(rendered).to include("Show tags")
      expect(rendered).to include("Hide tags")
    end

    it "shows English category and sector names" do
      expect(rendered).to include("Resilience")
      expect(rendered).to include("Education")
      expect(rendered).to include("Theme:")
    end
  end

  context "when spanish is true" do
    before do
      category.update!(name_spanish: "Resiliencia")
      type.update!(name_spanish: "Tema")
      sector.update!(name_spanish: "Educación")

      render partial: "workshops/show_tags",
             locals: { workshop: workshop, spanish: true }
    end

    it "shows Spanish tag labels" do
      expect(rendered).to include("Mostrar etiquetas")
      expect(rendered).to include("Ocultar etiquetas")
    end

    it "shows Spanish category and sector names" do
      expect(rendered).to include("Resiliencia")
      expect(rendered).to include("Educación")
      expect(rendered).to include("Tema:")
    end
  end

  context "when spanish is true but no Spanish translations exist" do
    before do
      render partial: "workshops/show_tags",
             locals: { workshop: workshop, spanish: true }
    end

    it "falls back to English names" do
      expect(rendered).to include("Resilience")
      expect(rendered).to include("Education")
      expect(rendered).to include("Theme:")
    end
  end
end
