class PasswordsController < Devise::PasswordsController
  skip_before_action :authenticate_user!, only: [ :new, :create, :edit, :update ]

  protected

  def after_resetting_password_path_for(resource)
    set_flash_message!(:notice, :password_updated) # custom flash message

    # normal after_resetting_password_path_for behavior
    resource_class.sign_in_after_reset_password ?
      after_sign_in_path_for(resource) :
      new_session_path(resource_name)
  end
end
