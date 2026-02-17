# frozen_string_literal: true

require "rails_helper"

RSpec.describe "User login", type: :system do
  let(:password) { "MyString" }

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
      expect(page).to have_content("Your account is locked")
    end
  end

  context "when user is inactive" do
    let(:user) { create(:user, password: password, inactive: true) }

    it "does not allow login and shows inactive message" do
      fill_in_login(user.email, password)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("inactive")
    end
  end

  context "when user exceeds maximum failed login attempts" do
    let(:user) { create(:user, password: password) }

    it "locks the account after 10 failed attempts and shows locked message" do
      10.times do
        fill_in_login(user.email, "wrong_password")
      end

      fill_in_login(user.email, password)

      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("Your account is locked")
      expect(user.reload.locked_at).to be_present
    end
  end

  context "when user is active and unlocked" do
    let(:user) { create(:user, password: password) }

    it "allows login successfully" do
      fill_in_login(user.email, password)

      expect(page).not_to have_content("Your account is locked")
      expect(page).not_to have_content("inactive")
      expect(page).to have_css("#avatar")
    end
  end
end
