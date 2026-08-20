require "rails_helper"

RSpec.describe "discounts/show", type: :view do
  let(:discount) { create(:discount) }

  before do
    assign(:discount, discount)
    render
  end

  it "shows discount amount" do
    expect(rendered).to have_content("$10")
  end

  it "links to allocations" do
    expect(rendered).to have_link("Allocations", href: allocations_path)
  end
end
