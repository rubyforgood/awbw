require "rails_helper"

RSpec.describe "Comments index per page", type: :system, js: true do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
    create_list(:comment, 12, commentable: create(:person))
  end

  it "shows the chosen number of comments and clears back to the default" do
    visit comments_path
    expect(page).to have_css("#aggregated_comments_list > div", count: 12)

    select "10", from: "number_of_items_per_page"
    expect(page).to have_css("#aggregated_comments_list > div", count: 10)

    click_link "Clear filters"
    expect(page).to have_css("#aggregated_comments_list > div", count: 12)
    expect(page).to have_select("number_of_items_per_page", selected: "25")
  end
end
