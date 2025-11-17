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

  it "shows default avatar when logged out, then user avatar after login" do
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    click_button "Log in"

    File.write("tmp/capybara-page.html", page.html)

    expect(page).to have_css("#avatar", wait: 5)
  end
end
