# spec/requests/passwords_spec.rb
require 'rails_helper'

RSpec.describe 'Passwords', type: :request do
  describe 'POST /password' do
    let(:user) { create(:user) }

    it 'sets the correct flash message' do
      post user_password_path, params: { user: { email: user.email } }
      if response.status == 500
        Rails.logger.error(response.body)
        puts response.body
      end
      expect(response).not_to have_http_status(500)

      follow_redirect!
      expect(flash[:notice]).to eq(
       "You will receive an email with instructions on how to reset your password in a few minutes. Contact us if you don't receive an email.")
    end
  end
end
