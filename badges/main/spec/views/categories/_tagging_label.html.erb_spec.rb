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
end
