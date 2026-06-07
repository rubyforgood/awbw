# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reset password (person)", type: :system do
  let(:person_user) { create(:user, :with_person) }

  def sign_in_via_form(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "MyString"
    click_button "Log in"
    expect(page).to have_no_link("Log In")
  end

  context "When user uses form to change password" do
    before do
      driven_by(:rack_test)
      sign_in person_user
      visit change_password_path
    end

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
    before do
      sign_in_via_form(person_user)
      visit change_password_path
    end

    # Skipped: intermittently fails in CI on the confirm-dialog/logout timing. See #1473.
    xit "logs the user out and lands on the password reset page when they choose to reset" do
      expect(page).to have_current_path(change_password_path)
      expect(page).to have_content("Don't remember your password?")
      expect(page).to have_link("Log out and reset it.")

      # Click "Log out and reset it." and accept the confirm dialog
      accept_confirm "This will log you out and send you to the password reset page. Continue?" do
        click_link "Log out and reset it."
      end

      # Confirm we are on the password reset page
      expect(page).to have_current_path(new_user_password_path)
      expect(page).to have_content("Forgot your password?")

      # Confirm user is logged out (nav shows Log In instead of avatar)
      expect(page).to have_link("Log In")
      expect(page).not_to have_css("#avatar")
    end
  end
end
