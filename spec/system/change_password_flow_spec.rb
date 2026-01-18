require 'rails_helper'

RSpec.describe 'Change Password Flow', type: :system do
  let(:user) { create(:user) }

  it 'allows the user to log out and reset their password' do
    sign_in user

    # Navigate to the change password page
    visit change_password_path

    # Click the "Log out and reset it" link
    accept_confirm do
      click_link 'Log out and reset it.'
    end

    # Verify redirection to the password reset page
    expect(page).to have_current_path(new_user_password_path)
  end
end
