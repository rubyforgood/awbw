require "rails_helper"

RSpec.describe "Unconfirmed user login", type: :request do
  let(:user) { create(:user, :unconfirmed, password: "password123") }

  it "includes a resend confirmation link in the flash message" do
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    expect(response).to redirect_to(new_user_session_path)
    follow_redirect!

    expect(response.body).to include("Resend confirmation email")
    expect(response.body).to include("/users/confirmation/new")
  end
end
