require 'rails_helper'

RSpec.describe "/users/welcome", type: :request do
  let(:user) { create(:user, confirmed_at: nil) }

  before do
    user.generate_welcome_instructions_token!
  end

  describe "GET /show" do
    context "with valid token" do
      it "renders successfully" do
        get user_welcome_url(user.welcome_instructions_token)
        expect(response).to be_successful
      end

      it "confirms user email" do
        get user_welcome_url(user.welcome_instructions_token)
        user.reload
        expect(user.confirmed_at).not_to be_nil
      end

      it "tracks auth.confirm event" do
        expect(Analytics::LifecycleBuffer).to receive(:push).with(
          hash_including(name: "auth.confirm")
        )
        get user_welcome_url(user.welcome_instructions_token)
      end

      it "only confirms once on multiple visits" do
        get user_welcome_url(user.welcome_instructions_token)
        first_confirmed_at = user.reload.confirmed_at

        # Visit again
        travel 1.hour do
          get user_welcome_url(user.welcome_instructions_token)
          expect(user.reload.confirmed_at).to eq(first_confirmed_at)
        end
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
    context "with valid token and password" do
      let(:valid_params) do
        {
          user: {
            password: "NewPassword123!",
            password_confirmation: "NewPassword123!"
          }
        }
      end

      it "sets the password" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
        user.reload
        expect(user.valid_password?("NewPassword123!")).to be true
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
        expect(controller.current_user).to eq(user)
      end

      it "redirects to users_path with notice" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
        expect(response).to redirect_to(users_path)
        expect(flash[:notice]).to include("Welcome")
      end

      it "tracks auth.password_set event" do
        allow(Analytics::LifecycleBuffer).to receive(:push)
        expect(Analytics::LifecycleBuffer).to receive(:push).with(
          hash_including(name: "auth.password_set")
        )
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
      end

      it "tracks auth.welcome_instructions_completed event" do
        allow(Analytics::LifecycleBuffer).to receive(:push)
        expect(Analytics::LifecycleBuffer).to receive(:push).with(
          hash_including(name: "auth.welcome_instructions_completed")
        )
        patch user_welcome_update_url(user.welcome_instructions_token), params: valid_params
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
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("problem setting your password")
      end

      it "does not clear invitation token" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: invalid_params
        user.reload
        expect(user.welcome_instructions_token).not_to be_nil
      end
    end

    context "without password (skip)" do
      it "clears invitation token" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: { user: { password: "" } }
        user.reload
        expect(user.welcome_instructions_token).to be_nil
      end

      it "redirects to sign in" do
        patch user_welcome_update_url(user.welcome_instructions_token), params: { user: { password: "" } }
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:notice]).to include("confirmed")
      end

      it "tracks auth.welcome_instructions_completed event" do
        allow(Analytics::LifecycleBuffer).to receive(:push)
        expect(Analytics::LifecycleBuffer).to receive(:push).with(
          hash_including(name: "auth.welcome_instructions_completed")
        )
        patch user_welcome_update_url(user.welcome_instructions_token), params: { user: { password: "" } }
      end
    end

    context "with invalid token" do
      it "redirects with alert" do
        patch user_welcome_update_url("invalid_token"), params: { user: { password: "Pass123!" } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include("Invalid invitation link")
      end
    end
  end
end
