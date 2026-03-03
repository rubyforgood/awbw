require "rails_helper"

RSpec.describe "Logout redirect", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "DELETE /users/sign_out" do
    it "redirects to root path for normal logout" do
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects to forgot password page when reset_password param is present" do
      delete destroy_user_session_path(reset_password: true)
      expect(response).to redirect_to(new_user_password_path)
    end
  end
end
