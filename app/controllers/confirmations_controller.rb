class ConfirmationsController < Devise::ConfirmationsController
  rescue_from(*EmailDeliveryErrorHandler::ERRORS) { |e| EmailDeliveryErrorHandler.handle(e, self) }

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


  # GET /users/confirmation/resend — one-click resend from the login flash
  def resend
    email = session.delete(:unconfirmed_email)

    if email.present?
      user = resource_class.send_confirmation_instructions(email: email)
      create_resend_notification(user) if user.errors.empty?
    end

    redirect_to new_user_session_path,
                notice: "If your email exists in our system, you will receive confirmation instructions shortly."
  end

  # POST /users/confirmation (resend)
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)

    if resource.errors.empty? || email_not_found?
      flash[:notice] = "If your email exists in our system, you will receive confirmation instructions shortly."
      redirect_to new_user_session_path
    elsif resource.confirmed_at.present?
      flash[:notice] = "Your email is already confirmed. Please sign in."
      redirect_to new_user_session_path
    else
      flash.now[:alert] = resource.errors.full_messages.join(", ")
      respond_with(resource)
    end
  end

  protected

  def after_confirmation_success(resource)
    if resource.previous_changes.key?("email")
      redirect_to new_user_session_path, notice: "Your email has been confirmed. Please sign in."
    elsif resource.welcome_instructions_token.present?
      redirect_to user_welcome_path(resource.welcome_instructions_token)
    else
      redirect_to new_user_session_path, notice: "Your email has been confirmed. Please sign in."
    end
  end

  private

  def email_not_found?
    resource.errors.any? { |e| e.attribute == :email && e.type == :not_found }
  end

  def create_resend_notification(user)
    NotificationServices::CreateNotification.call(
      noticeable: user,
      recipient_role: :person,
      recipient_email: user.email,
      kind: "account_confirmation",
      notification_type: 1,
      deliver: false,
      persist_delivered_email: false
    )
  end
end
