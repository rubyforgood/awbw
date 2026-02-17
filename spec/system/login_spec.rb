# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User login", type: :system do
  let(:password) { "MyString" }
  let(:generic_error) { "Invalid email or password. Please contact us for assistance." }

  def fill_in_login(email, password)
    visit new_user_session_path
    fill_in "user_email", with: email
    fill_in "user_password", with: password
    click_button "Log in"
  end

  context "when user is locked" do
    let(:user) { create(:user, :locked, password: password) }

    it "does not allow login and shows locked message" do
      fill_in_login(user.email, password)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("Please contact us for assistance.")
    end
  end

  context "when user is inactive" do
    let(:user) { create(:user, password: password, inactive: true) }

    it "does not allow login and shows generic error" do
      fill_in_login(user.email, password)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content(generic_error)
    end
  end

  context "when user exceeds maximum failed login attempts" do
    let(:user) { create(:user, password: password) }
    let(:last_attempt_warning) { "You have one more attempt before your account is locked" }

    it "warns on the last attempt then locks the account" do
      9.times do
        fill_in_login(user.email, "wrong_password")
      end

      expect(page).to have_content(last_attempt_warning)

      fill_in_login(user.email, "wrong_password")

      fill_in_login(user.email, password)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("Please contact us for assistance.")
      expect(user.reload.locked_at).to be_present
    end
  end

  context "when credentials are wrong" do
    let(:user) { create(:user, password: password) }

    it "shows generic error" do
      fill_in_login(user.email, "wrong_password")

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content(generic_error)
    end
  end

  context "when user is active and unlocked" do
    let(:user) { create(:user, password: password) }

    it "allows login successfully" do
      fill_in_login(user.email, password)

      expect(page).not_to have_content(generic_error)
      expect(page).to have_css("#avatar")
    end
  end
end
