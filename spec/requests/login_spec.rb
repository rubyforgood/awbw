require "rails_helper"

RSpec.describe "User login", type: :request do
  let(:password) { "MyString" }
  let(:generic_error) { "Invalid email or password. Please email us or fill out our Contact Us form for assistance." }

  def log_in(email, password)
    post user_session_path, params: { user: { email: email, password: password } }
  end

  context "when user is inactive" do
    let(:user) { create(:user, password: password, inactive: true) }

    it "does not allow login and shows the generic error" do
      log_in(user.email, password)

      expect(response).to redirect_to(new_user_session_path)
      follow_redirect!
      expect(response.body).to include(generic_error)
    end
  end

  context "when credentials are wrong" do
    let(:user) { create(:user, password: password) }

    it "shows the generic error" do
      log_in(user.email, "wrong_password")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(generic_error)
    end
  end

  context "when user is active and unlocked" do
    let(:user) { create(:user, password: password) }

    it "logs in successfully" do
      log_in(user.email, password)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).not_to include(generic_error)
    end
  end
end
