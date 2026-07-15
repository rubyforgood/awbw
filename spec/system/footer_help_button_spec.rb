require "rails_helper"

# The footer's floating help button is driven by the shared `dropdown`
# controller (no bespoke controller). Clicking it should reveal the help menu
# and clicking again should hide it.
RSpec.describe "Footer help button", type: :system do
  it "toggles the help menu open and closed" do
    visit faqs_path

    expect(page).to have_css("#fab-menu.hidden", visible: :all)

    find("#fab-button").click
    expect(page).to have_css("#fab-menu:not(.hidden)")
    expect(page).to have_link("FAQs")

    find("#fab-button").click
    expect(page).to have_css("#fab-menu.hidden", visible: :all)
  end
end
