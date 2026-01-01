require "rails_helper"

RSpec.describe "User login", type: :system do
  let(:user) { create(:user) }

  before do
    driven_by :selenium_chrome_headless
    Capybara.current_session.driver.browser.manage.window.resize_to(1400, 900) # desktop
  end

  it "shows default avatar when logged out" do
    visit unauthenticated_root_path
    expect(page).to_not have_css("#avatar")
    expect(page).to_not have_css("img[src*='missing.png']")
  end

  scenario "User login shows avatar only after login" do
    visit unauthenticated_root_path

    # Logged out state
    expect(page).not_to have_css("#avatar")

    # Log in
    sign_in user
    visit authenticated_root_path

    # Logged in state
    expect(page).to have_css("#avatar")
    expect(page).to have_css("#avatar-image")
  end
end
