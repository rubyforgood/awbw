# require "rails_helper"
#
# RSpec.describe "User login", type: :system do
#   let(:user) { create(:user) }
#
#   it "shows default avatar when logged out" do
#     visit root_path
#     expect(page).to_not have_css("#avatar")
#     expect(page).to_not have_css("img[src*='missing.png']")
#   end
#
#   scenario "User login shows avatar only after login" do
#     visit root_path
#
#     # Logged out state
#     expect(page).not_to have_css("#avatar")
#
#     # Log in
#     sign_in user
#     visit root_path
#
#     # Logged in state
#     expect(page).to have_css("#avatar")
#     expect(page).to have_css("#avatar-image")
#   end
# end
