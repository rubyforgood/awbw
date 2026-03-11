require 'rails_helper'

RSpec.describe "/users", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:valid_attributes) do
    {
      email: "jane.doe@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      confirmed_at: Time.current
    }
  end

  let(:invalid_attributes) do
    {
      email: "invalid_email", # assuming format validation exists
      password: "short",
      password_confirmation: "different"
    }
  end

  let(:new_attributes) do
    { email: "rosa.doe@example.com" }
  end

  # ---------------------------------------
  # INDEX
  # ---------------------------------------
  describe "GET /index" do
    context "as admin" do
      before do
        sign_in admin
        create_list(:user, 2)
      end

      it "renders successfully" do
        get users_url
        expect(response).to be_successful
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get users_url
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        get users_url
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # SHOW
  # ---------------------------------------
  describe "GET /show" do
    let(:user) { create(:user) }

    context "as admin" do
      before do
        sign_in admin
      end

      it "renders successfully" do
        get user_url(user)
        expect(response).to be_successful
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        get user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # NEW
  # ---------------------------------------
  describe "GET /new" do
    context "as admin" do
      before { sign_in admin }

      it "renders successfully" do
        get new_user_url
        expect(response).to be_successful
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get new_user_url
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        get new_user_url
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # EDIT
  # ---------------------------------------
  describe "GET /edit" do
    let(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      it "renders successfully" do
        get edit_user_url(user)
        expect(response).to be_successful
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get edit_user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        get edit_user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # CREATE
  # ---------------------------------------
  describe "POST /create" do
    context "as admin" do
      before { sign_in admin }

      context "with valid parameters" do
        it "creates a new User" do
          expect {
            post users_url, params: { user: valid_attributes }
          }.to change(User, :count).by(1)
        end

        it "redirects to the created user" do
          post users_url, params: { user: valid_attributes }
          expect(response).to redirect_to(user_url(User.last))
        end
      end

      context "with invalid parameters" do
        it "does not create a user" do
          expect {
            post users_url, params: { user: invalid_attributes }
          }.not_to change(User, :count)
        end

        it "returns 422" do
          post users_url, params: { user: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        post users_url, params: { user: valid_attributes }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        post users_url, params: { user: valid_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # UPDATE
  # ---------------------------------------
  describe "PATCH /update" do
    let(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      context "with valid parameters" do
        it "updates the user" do
          patch user_url(user), params: { user: new_attributes }
          user.reload
          expect(user.email).not_to eq(new_attributes[:email]) # bc confirmable hasn't gone through yet
          expect(user.unconfirmed_email).to eq(new_attributes[:email])
        end

        it "redirects to email change interstitial when email changes" do
          patch user_url(user), params: { user: new_attributes }
          expect(response).to redirect_to(confirm_email_change_user_path(user))
        end

        it "redirects to the updated user when email does not change" do
          patch user_url(user), params: { user: { time_zone: "Eastern Time (US & Canada)" } }
          expect(response).to redirect_to(user_url(user))
        end

        it "permits and updates time_zone" do
          user = User.create! valid_attributes
          patch user_url(user), params: { user: { time_zone: "Eastern Time (US & Canada)" } }
          user.reload
          expect(user.time_zone).to eq("Eastern Time (US & Canada)")
        end
      end

      context "with invalid parameters" do
        it "returns 422" do
          patch user_url(user), params: { user: invalid_attributes }
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        patch user_url(user), params: { user: { email: "hack@example.com" } }
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        patch user_url(user), params: { user: { email: "hack@example.com" } }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # DESTROY
  # ---------------------------------------
  describe "DELETE /destroy" do
    let!(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      it "destroys the user" do
        expect {
          delete user_url(user)
        }.to change(User, :count).by(-1)
      end

      it "redirects to index" do
        delete user_url(user)
        expect(response).to redirect_to(users_url)
      end

      it "does not destroy a user with created records and shows alert" do
        create(:workshop, created_by: user)
        expect {
          delete user_url(user)
        }.not_to change(User, :count)
        expect(response).to redirect_to(user_url(user))
        expect(flash[:alert]).to be_present
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "does not destroy user" do
        expect {
          delete user_url(user)
        }.not_to change(User, :count)
      end

      it "redirects to root" do
        delete user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "does not destroy user" do
        expect {
          delete user_url(user)
        }.not_to change(User, :count)
      end

      it "redirects to root" do
        delete user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # TOGGLE LOCK
  # ---------------------------------------
  describe "POST /toggle_lock_status" do
    let(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      it "locks user" do
        post toggle_lock_status_user_url(user)
        user.reload
        expect(user.locked_at).not_to be_nil
        expect(flash[:notice]).to eq("User has been locked.")
      end

      it "unlocks user" do
        user.update!(locked_at: Time.current)
        post toggle_lock_status_user_url(user)
        user.reload
        expect(user.locked_at).to be_nil
        expect(user.failed_attempts).to eq(0)
      end

      it "redirects to edit page" do
        post toggle_lock_status_user_url(user)
        expect(response).to redirect_to(edit_user_path(user))
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }
      it "does not change lock status" do
        original = user.locked_at
        post toggle_lock_status_user_url(user)
        user.reload
        expect(user.locked_at).to eq(original)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "does not change lock status" do
        original = user.locked_at
        post toggle_lock_status_user_url(user)
        user.reload
        expect(user.locked_at).to eq(original)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # CONFIRM EMAIL
  # ---------------------------------------
  describe "POST /confirm_email" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "as admin" do
      before { sign_in admin }

      it "confirms email" do
        post confirm_email_user_url(user)
        user.reload
        expect(user.confirmed_at).not_to be_nil
        expect(flash[:notice]).to eq("Email has been manually confirmed.")
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "does not confirm email and redirects to root" do
        post confirm_email_user_url(user)
        user.reload
        expect(user.confirmed_at).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "does not confirm email and redirects to root" do
        post confirm_email_user_url(user)
        user.reload
        expect(user.confirmed_at).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # EMAIL CHANGE INTERSTITIAL
  # ---------------------------------------
  describe "GET /confirm_email_change" do
    let(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      it "renders the email change interstitial" do
        user.update_columns(unconfirmed_email: "new@example.com")
        get confirm_email_change_user_path(user)
        expect(response).to have_http_status(:success)
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get confirm_email_change_user_path(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /process_email_change" do
    let(:user) { create(:user) }

    context "as admin" do
      before do
        sign_in admin
        user.update_columns(unconfirmed_email: "new@example.com")
      end

      it "sends confirmation email when selected" do
        post process_email_change_user_path(user), params: { send_confirmation: "1" }
        expect(response).to redirect_to(user_path(user))
        expect(flash[:notice]).to include("confirmation email has been sent")
      end

      it "skips confirmation email when not selected" do
        post process_email_change_user_path(user)
        expect(response).to redirect_to(user_path(user))
        expect(flash[:notice]).to eq("User was successfully updated.")
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        post process_email_change_user_path(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # MANUAL EMAIL CONFIRMATION INTERSTITIAL
  # ---------------------------------------
  describe "GET /confirm_email_manual" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "as admin" do
      before { sign_in admin }

      it "renders the manual confirmation interstitial" do
        get confirm_email_manual_user_path(user)
        expect(response).to have_http_status(:success)
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get confirm_email_manual_user_path(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /process_email_manual" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "as admin" do
      before { sign_in admin }

      it "manually confirms email" do
        post process_email_manual_user_path(user), params: { confirm_action: "confirm" }
        user.reload
        expect(user.confirmed_at).not_to be_nil
        expect(flash[:notice]).to include("manually confirmed")
      end

      it "resends confirmation email" do
        post process_email_manual_user_path(user), params: { confirm_action: "resend" }
        expect(response).to redirect_to(user_path(user))
        expect(flash[:notice]).to include("Confirmation email has been resent")
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        post process_email_manual_user_path(user), params: { confirm_action: "confirm" }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # SEND INVITATION
  # ---------------------------------------
  describe "POST /send_welcome_instructions" do
    let(:user) { create(:user, confirmed_at: nil) }

    context "as admin" do
      before { sign_in admin }

      it "generates invitation token" do
        post send_welcome_instructions_user_url(user)
        user.reload
        expect(user.welcome_instructions_token).not_to be_nil
        expect(user.welcome_instructions_created_at).not_to be_nil
        expect(user.welcome_instructions_sent_at).not_to be_nil
      end

      xit "sends welcome email" do # TODO fix this testing to make sure notification and email get sent
        expect {
          post send_welcome_instructions_user_url(user)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "redirects with notice" do
        post send_welcome_instructions_user_url(user)
        expect(flash[:notice]).to include("Invitation sent")
        expect(response).to redirect_to(users_path)
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "does not send invitation and redirects to root" do
        post send_welcome_instructions_user_url(user)
        user.reload
        expect(user.welcome_instructions_token).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "does not send invitation and redirects to root" do
        post send_welcome_instructions_user_url(user)
        user.reload
        expect(user.welcome_instructions_token).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------
  # SEND RESET PASSWORD INSTRUCTIONS
  # ---------------------------------------
  describe "POST /send_reset_password_instructions" do
    let(:user) { create(:user) }

    context "as admin" do
      before { sign_in admin }

      it "sends reset password instructions and redirects with notice" do
        post send_reset_password_instructions_user_url(user)
        expect(flash[:notice]).to include("Reset password instructions sent")
        expect(response).to redirect_to(users_path)
      end
    end

    context "as regular_user" do
      before { sign_in regular_user }

      it "redirects to root" do
        post send_reset_password_instructions_user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to root" do
        post send_reset_password_instructions_user_url(user)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
