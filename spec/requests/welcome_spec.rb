require 'rails_helper'

RSpec.describe "/users/welcome", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  before do
    user.set_welcome_instructions_token!
  end

  describe "GET /show" do
    context "with valid token" do
      it "renders successfully" do
        get user_welcome_url(user.welcome_instructions_token)
        expect(response).to be_successful
      end

      it "does NOT confirm user email" do
        user.update!(confirmed_at: nil)

        get user_welcome_url(user.welcome_instructions_token)
        expect(user.reload.confirmed_at).to be_nil
      end
    end

    context "with invalid token" do
      it "redirects with alert" do
        get user_welcome_url("invalid_token")
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Invalid invitation link")
      end
    end

    context "with expired token" do
      it "redirects with alert" do
        user.update_columns(welcome_instructions_created_at: 31.days.ago)

        get user_welcome_url(user.welcome_instructions_token)

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("expired")
      end
    end
  end

  describe "PATCH /update" do
    let(:valid_params) do
      {
        user: {
          password: "NewPassword123!",
          password_confirmation: "NewPassword123!"
        }
      }
    end

    context "with valid token and password" do
      it "sets the password" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
        expect(user.reload.valid_password?("NewPassword123!")).to be true
      end

      it "clears invitation token" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params

        user.reload
        expect(user.welcome_instructions_token).to be_nil
        expect(user.welcome_instructions_created_at).to be_nil
        expect(user.welcome_instructions_sent_at).to be_nil
      end

      it "signs in the user" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
        expect(request.env['warden'].user).to eq(user)
      end

      it "redirects to root with notice" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to include("Welcome")
      end

      it "tracks first-time password_set event" do
        events = []
        allow(Analytics::LifecycleBuffer).to receive(:push) { |payload| events << payload }

        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params

        expect(events.any? { |e| e[:name] == "auth.password_first_set" }).to be true
      end
    end

    context "with invalid password" do
      let(:invalid_params) do
        {
          user: {
            password: "short",
            password_confirmation: "different"
          }
        }
      end

      it "renders show with error" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: invalid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("problem setting your password")
      end

      it "does not clear invitation token" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: invalid_params

        expect(user.reload.welcome_instructions_token).not_to be_nil
      end
    end

    context "with invalid token" do
      it "redirects with alert" do
        patch user_welcome_update_url("invalid_token"),
              params: { user: { password: "Pass123!" } }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Invalid invitation link")
      end
    end
  end
end
