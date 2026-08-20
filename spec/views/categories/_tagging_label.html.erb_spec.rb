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

  context "when the category is hidden from the public (unpublished)" do
    let(:category) { create(:category, :unpublished, name: "Resilience", category_type: type) }

    it "renders a muted grey chip with the closed-eye hidden icon" do
      render partial: "categories/tagging_label",
             locals: { category: category, name_only: true }

      expect(rendered).to include("Hidden from the public")
      expect(rendered).to include("bg-gray-100")
      expect(rendered).not_to include(DomainTheme.bg_class_for(:sectors))
    end
  end
end
