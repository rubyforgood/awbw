require 'rails_helper'

RSpec.describe "sectors/index", type: :view do
  let(:admin) { create(:user, :admin) }

  before do
    assign(:sectors, [
      create(:category, name: "Sector One", published: true),
      create(:category, name: "Sector Two", published: false)
    ])
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders each category with name, type, and published label" do
    render

    # NAME
    expect(rendered).to include("Sector One")
    expect(rendered).to include("Sector Two")

    # PUBLISHED?
    expect(rendered).to include("Yes") # for first category
    expect(rendered).to include("No")  # for second category
  end
end
