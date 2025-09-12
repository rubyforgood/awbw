class PasswordsController < Devise::PasswordsController
  
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      NotificationMailer.reset_password_notification(resource).deliver_later
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end

  protected

  def after_resetting_password_path_for(resource)
    set_flash_message!(:notice, :password_updated)
    resource_class.sign_in_after_reset_password ? after_sign_in_path_for(resource) : new_session_path(resource_name)
  end
end
