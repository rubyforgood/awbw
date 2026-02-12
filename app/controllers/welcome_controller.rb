class WelcomeController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :find_user_by_welcome_instructions_token
  before_action :validate_welcome_instructions_token

  # Skip authorization check for welcome pages
  def verify_authorized
    # Intentionally skip authorization - this is a public page with token validation
  end

  def show
    # users get sent here after visiting confirmations_controller
    # render set password form
  end

  def update
    if @user.update(password_params)
      @user.track_auth_event("auth.password_first_set")
      @user.clear_welcome_instructions_token!
      @user.track_auth_event("auth.account_setup_completed")

      sign_in(@user)
      redirect_to root_path,
                  notice: "Welcome! Your password has been set successfully."
    else
      flash.now[:alert] = "There was a problem setting your password."
      render :show, status: :unprocessable_content
    end
  end

  private

  def find_user_by_welcome_instructions_token
    @user = User.find_by(welcome_instructions_token: params[:welcome_instructions_token])
    return if @user
    redirect_to root_path, alert: "Invalid invitation link." and return
  end

  def validate_welcome_instructions_token
    return if @user.welcome_instructions_token_valid?
    redirect_to root_path,
                alert: "This invitation link has expired. Please contact an administrator." and return
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
