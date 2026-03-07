require 'rails_helper'

RSpec.describe "categories/_tagging_label", type: :view do
  let(:type)     { create(:category_type, name: "Theme") }
  let(:category) { create(:category, :published, name: "Resilience", category_type: type) }

  it "shows type prefix by default" do
    render partial: "categories/tagging_label",
           locals: { category: category }

    expect(rendered).to include("Theme:")
  end

  it "hides type prefix when name_only" do
    render partial: "categories/tagging_label",
           locals: { category: category, name_only: true }

    expect(rendered).not_to include("Theme:")
  end

  context "when spanish is true" do
    it "shows Spanish name when present" do
      category.update!(name_spanish: "Resiliencia")
      type.update!(name_spanish: "Tema")

      render partial: "categories/tagging_label",
             locals: { category: category, spanish: true }

      expect(rendered).to include("Tema:")
      expect(rendered).to include("Resiliencia")
    end

    it "falls back to English name when Spanish name is blank" do
      render partial: "categories/tagging_label",
             locals: { category: category, spanish: true }

      expect(rendered).to include("Theme:")
      expect(rendered).to include("Resilience")
    end
  end
end
