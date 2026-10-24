require "rails_helper"

RSpec.describe "Comments index filters", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:rows) { "#aggregated_comments_list > div" }

  before do
    sign_in admin
    create_list(:comment, 12, commentable: create(:person))
    create(:comment, commentable: create(:workshop), body: "Workshop note", flagged: true)
  end

  it "shows the chosen number of comments and clears back to the default" do
    visit comments_path
    expect(page).to have_css(rows, count: 13)

    select "10", from: "number_of_items_per_page"
    expect(page).to have_css(rows, count: 10)

    click_link "Clear filters"
    expect(page).to have_css(rows, count: 13)
    expect(page).to have_select("number_of_items_per_page", selected: "25")
  end

  it "submits the keyword, type, and flagged filters" do
    visit comments_path

    fill_in "query", with: "Workshop note"
    expect(page).to have_css(rows, count: 1)

    click_link "Clear filters"
    expect(page).to have_css(rows, count: 13)

    select "Workshops", from: "source"
    expect(page).to have_css(rows, count: 1)

    click_link "Clear filters"
    expect(page).to have_css(rows, count: 13)

    find("label[title='Flagged for follow-up']").click
    expect(page).to have_css(rows, count: 1, text: "Workshop note")
  end
end
