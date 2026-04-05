module LoginHelpers
  def system_sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: user.password
    click_button "Log in"
    expect(page).to have_no_link("Log In")
  end
end

RSpec.configure do |config|
  config.include LoginHelpers, type: :system
end
