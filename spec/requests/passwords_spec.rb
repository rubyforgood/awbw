# spec/requests/passwords_spec.rb
require 'rails_helper'

RSpec.describe 'Passwords', type: :request do
  describe 'POST /password' do
    let(:user) { create(:user) }

    it 'sets the correct flash message' do
      post user_password_path, params: { user: { email: user.email } }
      expect(flash[:notice]).to eq(
       "You will receive an email with instructions on how to reset your password in a few minutes. Contact us if you don't receive an email.")
    end
  end
end
