require "rails_helper"

RSpec.describe "Unconfirmed user login", type: :request do
  let(:user) { create(:user, :unconfirmed, password: "password123") }

  it "includes a resend confirmation link in the flash message" do
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    expect(response).to redirect_to(new_user_session_path)
    follow_redirect!

    expect(response.body).to include("Resend confirmation email")
    expect(response.body).to include("/users/confirmation/resend")
  end

  it "stores the attempted email in the session" do
    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    expect(session[:unconfirmed_email]).to eq(user.email)
  end

  describe "GET /users/confirmation/resend" do
    it "sends confirmation instructions and redirects to login" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect {
        get resend_user_confirmation_path
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include("you will receive confirmation instructions")
    end

    it "clears the session email after resending" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }
      get resend_user_confirmation_path

      expect(session[:unconfirmed_email]).to be_nil
    end

    it "creates a system notification" do
      post user_session_path, params: { user: { email: user.email, password: "password123" } }

      expect {
        get resend_user_confirmation_path
      }.to change { Notification.where(kind: "account_confirmation").count }.by(1)
    end

    it "does not create a notification when no email is in session" do
      expect {
        get resend_user_confirmation_path
      }.not_to change { Notification.count }
    end

    it "redirects gracefully when no email is in session" do
      get resend_user_confirmation_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
