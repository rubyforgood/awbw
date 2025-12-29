require 'rails_helper'

RSpec.describe "categories/index", type: :view do
  let(:admin) { create(:user, :admin) }

  let!(:type_a) { create(:category_type, name: "Type A") }
  let!(:type_b) { create(:category_type, name: "Type B") }

  before do
    assign(:categories, [
      create(:category, name: "Category One", category_type: type_a, published: true),
      create(:category, name: "Category Two", category_type: type_b, published: false)
    ])

    assign(:category_types, [ type_a, type_b ])

    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders each category with name, type, and published label" do
    render

    # NAME
    expect(rendered).to include("Category One")
    expect(rendered).to include("Category Two")

    # CATEGORY TYPE
    expect(rendered).to include("Type A")
    expect(rendered).to include("Type B")

    # PUBLISHED?
    expect(rendered).to include("Yes") # for first category
    expect(rendered).to include("No")  # for second category
  end
end
