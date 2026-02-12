require 'rails_helper'

# This spec tests the complete user invitation flow from admin invite to user password setup
# It simulates the system flow but uses request specs since Chrome/Selenium isn't available in Docker
RSpec.describe 'User Invitation Flow (System Test)', type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:unconfirmed_user) do
    create(:user,
           email: 'newuser@example.com',
           first_name: 'New',
           last_name: 'User',
           confirmed_at: nil,
           confirmation_token: 'old_token_123',
           confirmation_sent_at: 1.day.ago)
  end

  describe 'Complete invitation flow' do
    it 'allows admin to invite user, user confirms email, and sets password' do
      # Step 1: Admin logs in
      sign_in admin
      
      # Step 2: Admin sends invitation via POST to send_welcome_instructions
      post send_welcome_instructions_user_path(unconfirmed_user)
      expect(response).to redirect_to(users_path)
      follow_redirect!
      expect(response.body).to include('Invitation sent')
      
      # Verify user has welcome token and new confirmation token
      unconfirmed_user.reload
      expect(unconfirmed_user.welcome_instructions_token).to be_present
      expect(unconfirmed_user.welcome_instructions_sent_at).to be_present
      expect(unconfirmed_user.confirmation_token).to be_present
      expect(unconfirmed_user.confirmation_token).not_to eq('old_token_123')
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
      expect(response.body).to include('Set a password to complete your account setup')
      
      # Step 7: User submits password on welcome page
      patch user_welcome_update_path(welcome_token), params: {
        user: {
          password: 'SecurePassword123!',
          password_confirmation: 'SecurePassword123!'
        }
      }
      
      # Step 8: Verify auth.password_first_set event was tracked
      # (This is tested in welcome_spec.rb with proper mocking)
      
      # Step 9: User should be logged in and redirected to root_path
      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include('Welcome! Your password has been set successfully')
      
      # Verify welcome token is cleared
      unconfirmed_user.reload
      expect(unconfirmed_user.welcome_instructions_token).to be_nil
      expect(unconfirmed_user.welcome_instructions_created_at).to be_nil
      expect(unconfirmed_user.welcome_instructions_sent_at).to be_nil
      
      # Verify user is logged in by checking Warden
      expect(warden.user).to eq(unconfirmed_user)
      
      # Verify user can access authenticated pages
      get users_path
      expect(response).to be_successful
    end
  end
  
  describe 'Edge cases' do
    it 'handles expired confirmation token (> 3 days)' do
      # Create user with expired confirmation token
      expired_user = create(:user,
                            email: 'expired@example.com',
                            confirmed_at: nil,
                            confirmation_sent_at: 4.days.ago)
      expired_user.set_welcome_instructions_token!
      
      # Try to visit confirmation page with expired token
      get user_confirmation_path(confirmation_token: expired_user.confirmation_token)
      
      # Should show error on confirmations/new page
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Confirmation token is invalid')
    end
    
    it 'redirects already confirmed users without welcome token to sign in' do
      # Create confirmed user without welcome token
      confirmed_user = create(:user, confirmed_at: Time.current)
      confirmed_user.update_columns(welcome_instructions_token: nil)
      
      # Generate a new confirmation email (simulating re-confirmation)
      confirmed_user.send_confirmation_instructions
      
      # Visit confirmation link - should redirect to sign in with message
      get user_confirmation_path(confirmation_token: confirmed_user.confirmation_token)
      
      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include('confirmed')
    end
    
    it 'handles invalid/missing confirmation token' do
      get user_confirmation_path(confirmation_token: 'invalid_token_12345')
      
      # Should render new confirmations page with error
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Confirmation token is invalid')
    end
    
    it 'redirects to welcome page if user has valid welcome token' do
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
    
    it 'redirects to sign in if user has no welcome token' do
      # User without welcome token
      user_without_token = create(:user, confirmed_at: nil)
      user_without_token.update_columns(welcome_instructions_token: nil)
      user_without_token.send_confirmation_instructions
      
      # Visit confirmation link
      get user_confirmation_path(confirmation_token: user_without_token.confirmation_token)
      
      # Should redirect to sign in page
      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include('confirmed')
    end
  end
end
