require 'rails_helper'

RSpec.describe 'Facilitators can change their password quickly and easily' do
  describe 'Facilitator changes password through reset link' do
    context 'when facilitator requests password change' do
      before do
        @user = create(:user)
        create(:facilitator, user: @user)
      end

      it 'completes the full password reset flow successfully' do
        visit '/users/sign_in'

        expect(page).to have_content('Log in')
        expect(page).to have_content('Email')
        expect(page).to have_content('Password')
        expect(page).to have_link('Forgot your password?')

        click_link('Forgot your password?')

        expect(page).to have_current_path('/users/password/new')
        expect(page).to have_content('Forgot your password?')

        fill_in 'user_email', with: @user.email
        click_button 'Email me reset password instructions'

        expect(page).to have_content(
          'You will receive an email with instructions on how to reset your password in a few minutes.'
        )

        # Retrieve Reset Link from Email
        notification = Notification.find_by(
          kind: 'reset_password',
          recipient_email: @user.email
        )

        email_body = notification.email_body_text
        path_match = email_body.match(%r{/users/password/edit\?reset_password_token=[^\s]+})
        reset_path = path_match[0]

        # Set new password
        visit reset_path

        fill_in 'New password', with: 'NewPassword123!'
        fill_in 'Confirm new password', with: 'NewPassword123!'
        click_button 'Set password'

        expect(page).to have_content('Your password has been set successfully')
        expect(page).to have_current_path('/')

        # Test Login with New Password
        sign_out @user

        visit '/users/sign_in'
        fill_in 'user_email', with: @user.email
        fill_in 'user_password', with: 'NewPassword123!'
        click_button 'Log in'

        expect(page).to have_content('Signed in successfully')

        # Verify Old Password is Invalid
        sign_out @user

        visit '/users/sign_in'
        fill_in 'user_email', with: @user.email
        fill_in 'user_password', with: 'wrongpassword'
        click_button 'Log in'

        expect(page).to have_content('Invalid Email or password.')
      end
    end
  end
end
