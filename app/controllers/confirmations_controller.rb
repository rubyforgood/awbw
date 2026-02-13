class ConfirmationsController < Devise::ConfirmationsController
  # GET /users/confirmation?confirmation_token=...

  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.none?
      after_confirmation_success(resource)

    elsif resource.confirmed?
      redirect_to new_user_session_path,
                  notice: "Your email is already confirmed. Please sign in."

    else
      respond_with_navigational(resource.errors, status: :unprocessable_content) do
        flash.now[:alert] = "Confirmation token is invalid. Please request a new confirmation email."
        render :new, status: :unprocessable_content
      end
    end
  end

  # POST /users/confirmation (resend)
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)

    if resource.errors.empty?
      redirect_to new_user_session_path,
                  notice: "If your email exists in our system, you will receive confirmation instructions shortly."
    elsif resource.confirmed_at.present?
      redirect_to new_user_session_path,
                  notice: "Your email is already confirmed. Please sign in."
    else
      respond_with(resource)
    end
  end

  protected

  def after_confirmation_success(resource)
    if resource.welcome_instructions_token_valid?
      redirect_to user_welcome_path(resource.welcome_instructions_token)
    else
      redirect_to new_user_session_path,
                  notice: "Your email has been confirmed. Please sign in."
    end
  end
end
