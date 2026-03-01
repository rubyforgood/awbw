require "rails_helper"

RSpec.describe "users/index", type: :view do
  let(:admin_user) { create(:user, :admin) }

  before do
    allow(view).to receive(:current_user).and_return(admin_user)
    render
  end

  it "renders the page header" do
    expect(rendered).to have_selector("h1", text: "Users")
  end

  it "renders the search form" do
    expect(rendered).to have_field("search")
    expect(rendered).to have_select("access")
    expect(rendered).to have_select("super_user")
  end

  it "renders a turbo frame for results" do
    expect(rendered).to have_selector("turbo-frame#users_results")
  end

  it "renders skeleton loader table with correct columns" do
    expect(rendered).to have_selector("table thead tr th", text: "Email")
    expect(rendered).to have_selector("table thead tr th", text: "Person")
    expect(rendered).to have_selector("table thead tr th", text: "Confirmed")
    expect(rendered).to have_selector("table thead tr th", text: "Access")
    expect(rendered).to have_selector("table thead tr th", text: "Admin")
  end

  it "renders skeleton rows" do
    expect(rendered).to have_selector("table tbody tr", count: 8)
  end
end
