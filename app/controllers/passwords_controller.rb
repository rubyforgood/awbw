class PasswordsController < Devise::PasswordsController
  skip_before_action :authenticate_user!, only: [ :new, :create, :edit, :update ]

  def create
    super do |resource|
      track_event("auth.password_reset_requested", user_id: resource.id) if resource.persisted?
    end
  end

  def update
    super do |resource|
      track_event("auth.password_changed", user_id: resource.id) if resource.errors.empty?
    end
  end

  protected

  def after_resetting_password_path_for(resource)
    set_flash_message!(:notice, :password_updated) # custom flash message

    # normal after_resetting_password_path_for behavior
    resource_class.sign_in_after_reset_password ?
      after_sign_in_path_for(resource) :
      new_session_path(resource_name)
  end
end
