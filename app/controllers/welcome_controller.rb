class WelcomeController < ApplicationController
  skip_before_action :authenticate_user!
  
  before_action :find_user_by_welcome_instructions_token
  before_action :validate_welcome_instructions_token
  
  # Skip authorization check for welcome pages
  def verify_authorized
    # Intentionally skip authorization - this is a public page with token validation
  end

  def show
    # Confirm the user's email immediately when they visit the welcome page
    # The tracking will be handled by the User model callback
    @user.update(confirmed_at: Time.current) unless @user.confirmed_at.present?
  end

  def update
    if params[:user][:password].present?
      if @user.reset_password(params[:user][:password], params[:user][:password_confirmation])
        @user.clear_welcome_instructions_token!
        @user.track_auth_event("auth.password_set")
        @user.track_auth_event("auth.welcome_instructions_completed")
        sign_in(@user)
        redirect_to users_path, notice: "Welcome! Your password has been set successfully."
      else
        flash.now[:alert] = "There was a problem setting your password."
        render :show, status: :unprocessable_entity
      end
    else
      # User visited the page but didn't set a password
      @user.clear_welcome_instructions_token!
      @user.track_auth_event("auth.welcome_instructions_completed")
      redirect_to new_user_session_path, notice: "Your email has been confirmed. Please log in."
    end
  end

  private

  def find_user_by_welcome_instructions_token
    @user = User.find_by(welcome_instructions_token: params[:welcome_instructions_token])
    return if @user

    redirect_to root_path, alert: "Invalid invitation link."
  end

  def validate_welcome_instructions_token
    return if @user.welcome_instructions_token_valid?

    redirect_to root_path, alert: "This invitation link has expired. Please contact an administrator."
  end
end
