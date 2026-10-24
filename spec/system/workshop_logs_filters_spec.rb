require "rails_helper"

RSpec.describe "Workshop logs filters", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:submitter) { create(:user, :with_person) }
  let(:rows) { "tr[id^='workshop_log_']" }

  before do
    sign_in admin
    create_list(:workshop_log, 12, created_by: submitter, workshop_held_on: Date.new(2026, 3, 1))
    create(:workshop_log, created_by: admin, workshop_held_on: Date.new(2025, 3, 1))
  end

  it "pages by the chosen size and clears back to the default" do
    visit workshop_logs_path
    expect(page).to have_css(rows, count: 10)

    select "25", from: "number_of_items_per_page"
    expect(page).to have_current_path(/number_of_items_per_page=25/)
    expect(page).to have_css(rows, count: 13)

    click_link "Clear filters"
    expect(page).to have_css(rows, count: 10)
    expect(page).to have_select("number_of_items_per_page", selected: "10")
  end

  it "submits a select filter on change" do
    visit workshop_logs_path(number_of_items_per_page: 25)

    select "2025", from: "year"
    expect(page).to have_current_path(/year=2025/)
    expect(page).to have_css(rows, count: 1)
    expect(page).to have_select("number_of_items_per_page", selected: "25")
  end

  it "submits the submitted-by search box on change, even after another filter refreshed the page" do
    visit workshop_logs_path(number_of_items_per_page: 25)
    select "2026", from: "year"
    expect(page).to have_current_path(/year=2026/)

    find("#created_by_id + .ts-wrapper").click
    find(".ts-dropdown .option", text: submitter.full_name).click
    expect(page).to have_current_path(/created_by_id=#{submitter.id}/)
    expect(page).to have_css(rows, count: 12)
  end

  it "keeps focus in the author box when typing pauses long enough to submit" do
    visit workshop_logs_path

    find_field("author_name").send_keys("Nobody")
    expect(page).to have_current_path(/author_name=Nobody/)
    expect(page).to have_no_css(rows)
    page.driver.browser.action.send_keys(" here").perform

    expect(page).to have_current_path(/author_name=Nobody\+here/)
    expect(page).to have_field("author_name", with: "Nobody here")
  end
end
