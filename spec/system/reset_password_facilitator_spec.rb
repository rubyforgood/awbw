# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reset password (facilitator)', type: :system do
  let(:facilitator_user) { create(:user, :with_facilitator) }

  before do
    sign_in facilitator_user
    # Start on a page where the user nav is visible
    visit root_path
    # Open user nav dropdown
    find('#avatar button').click
    # Click "Change password"
    click_link 'Change password'
  end

  context "When user uses form to change password" do
    it "fills out the form, submits, and stays logged in" do
      expect(page).to have_current_path(change_password_path)

      fill_in id: "user_current_password", with: "MyString"
      fill_in "change-password-new-password", with: "new_secure_password"
      fill_in "change-password-new-password-confirmation", with: "new_secure_password"
      click_button "Change Password"

      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Your Password was updated.")
      expect(page).to have_css("#avatar")
    end
  end

  context "When user opts to 'Log out and reset' for forgotten passwords" do
    it 'logs the user out and lands on the password reset page when they choose to reset' do
      # Should be on the change password page
      expect(page).to have_current_path(change_password_path)

      # Click "Log out and reset it." and accept the confirm dialog
      accept_confirm do
        click_link 'Log out and reset it.'
      end

      # Confirm we are on the password reset page
      expect(page).to have_current_path(new_user_password_path)
      expect(page).to have_content('Forgot your password?')

      # Confirm user is logged out (nav shows Log In instead of avatar)
      expect(page).to have_link('Log In')
      expect(page).not_to have_css('#avatar')
    end
  end
end
