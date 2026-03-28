require "rails_helper"

# This spec tests the complete user invitation flow from admin invite to user password setup
# It simulates the system flow but uses request specs since Chrome/Selenium isn"t available in Docker
RSpec.describe "User Invitation Flow (System Test)", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:unconfirmed_user) do
    create(:user,
           email: "newuser@example.com",
           confirmed_at: nil,
           confirmation_token: "old_token_123",
           confirmation_sent_at: 1.day.ago)
  end

  describe "Complete invitation flow" do
    it "allows admin to invite user, user confirms email, and sets password" do
      # Step 1: Admin logs in
      sign_in admin

      # Step 2: Admin sends invitation via POST to send_welcome_instructions
      post send_welcome_instructions_user_path(unconfirmed_user)
      expect(response).to redirect_to(users_path)
      follow_redirect!
      expect(response.body).to include("Invitation sent")

      # Verify user has welcome token and new confirmation token
      unconfirmed_user.reload
      expect(unconfirmed_user.welcome_instructions_token).to be_present
      expect(unconfirmed_user.welcome_instructions_sent_at).to be_present
      expect(unconfirmed_user.confirmation_token).to be_present
      # expect(unconfirmed_user.confirmation_token).not_to eq("old_token_123")
      expect(unconfirmed_user.confirmed_at).to be_nil

      confirmation_token = unconfirmed_user.confirmation_token
      welcome_token = unconfirmed_user.welcome_instructions_token

      # Step 3: Admin logs out
      sign_out admin

      # Step 4: User clicks confirmation link from email (simulates email click)
      get user_confirmation_path(confirmation_token: confirmation_token)

      # Step 5: Should be redirected to welcome page (user_welcome_path)
      expect(response).to redirect_to(user_welcome_path(welcome_token))

      # Verify user is now confirmed
      unconfirmed_user.reload
      expect(unconfirmed_user.confirmed_at).to be_present

      # Step 6: User visits welcome page and sees password form
      get user_welcome_path(welcome_token)
      expect(response).to be_successful
      expect(response.body).to include("Set a password to complete your account setup")

      # Step 7: User submits password on welcome page
      patch user_welcome_update_path(welcome_token), params: {
        user: {
          password: "SecurePassword123!",
          password_confirmation: "SecurePassword123!"
        }
      }

      # Step 8: Verify auth.password_first_set event was tracked
      # (This is tested in welcome_spec.rb with proper mocking)

      # Step 9: User should be logged in and redirected to root_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Welcome! Your password has been set successfully")

      # Verify welcome token is cleared
      unconfirmed_user.reload
      expect(unconfirmed_user.welcome_instructions_token).to be_nil
      expect(unconfirmed_user.welcome_instructions_created_at).to be_nil
      expect(unconfirmed_user.welcome_instructions_sent_at).to be_nil

      # Verify user is logged in by checking Warden
      expect(session["warden.user.user.key"]).to be_present

      # Verify user can access authenticated pages
      get workshop_logs_path # Example authenticated page for non-admin users
      expect(response).to be_successful
    end
  end

  describe "Edge cases" do
    it "confirms user with old confirmation token (no expiry)" do
      old_user = create(:user,
                        email: "old_token@example.com",
                        confirmed_at: nil)
      old_user.send_confirmation_instructions
      old_user.reload

      old_token = old_user.confirmation_token

      # Age token well beyond previous 3-day limit
      old_user.update_column(:confirmation_sent_at, 30.days.ago)

      old_user.set_welcome_instructions_token!

      get user_confirmation_path(confirmation_token: old_token)

      expect(response).to have_http_status(:redirect)
      old_user.reload
      expect(old_user.confirmed?).to be true
    end

    it "redirects already confirmed users without welcome token to sign in" do
      # Create confirmed user without welcome token
      confirmed_user = create(:user, confirmed_at: Time.current)
      confirmed_user.update_columns(welcome_instructions_token: nil)

      # Generate a new confirmation email (simulating re-confirmation)
      confirmed_user.send_confirmation_instructions

      # Visit confirmation link - should redirect to sign in with message
      get user_confirmation_path(confirmation_token: confirmed_user.confirmation_token)

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("confirmed")
    end

    it "handles invalid/missing confirmation token" do
      get user_confirmation_path(confirmation_token: "invalid_token_12345")

      # Should render new confirmations page with error
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Confirmation token is invalid")
    end

    it "redirects to welcome page if user has valid welcome token" do
      # User with valid welcome token
      user_with_token = create(:user, confirmed_at: nil)
      user_with_token.set_welcome_instructions_token!
      user_with_token.send_confirmation_instructions

      # Visit confirmation link
      get user_confirmation_path(confirmation_token: user_with_token.confirmation_token)

      # Should redirect to welcome page
      user_with_token.reload
      expect(response).to redirect_to(user_welcome_path(user_with_token.welcome_instructions_token))
    end

    it "regenerates welcome token and redirects to welcome page if token is expired" do
      # User with expired welcome token
      user_with_expired_token = create(:user, confirmed_at: nil)
      user_with_expired_token.set_welcome_instructions_token!
      user_with_expired_token.update_column(:welcome_instructions_created_at, 31.days.ago)
      old_token = user_with_expired_token.welcome_instructions_token
      user_with_expired_token.send_confirmation_instructions

      # Visit confirmation link
      get user_confirmation_path(confirmation_token: user_with_expired_token.confirmation_token)

      # Should regenerate welcome token and redirect to welcome page
      user_with_expired_token.reload
      expect(user_with_expired_token.welcome_instructions_token).to be_present
      expect(user_with_expired_token.welcome_instructions_token).not_to eq(old_token)
      expect(response).to redirect_to(user_welcome_path(user_with_expired_token.welcome_instructions_token))
    end

    it "redirects existing users to root on email change reconfirmation" do
      # Existing user who has signed in before and is changing their email
      existing_user = create(:user, confirmed_at: 1.year.ago)
      existing_user.update_column(:sign_in_count, 5)
      existing_user.update_columns(
        unconfirmed_email: "newemail@example.com",
        confirmation_token: Devise.friendly_token,
        confirmation_sent_at: Time.current
      )

      get user_confirmation_path(confirmation_token: existing_user.confirmation_token)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("confirmed")
    end
  end
end
