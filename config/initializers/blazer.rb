# Blazer authentication configuration
# Only allow super_users to access Blazer
Rails.application.config.to_prepare do
  Blazer::BaseController.class_eval do
    before_action :authenticate_user!
    before_action :require_blazer_access

    private

    def require_blazer_access
      redirect_to root_path, alert: "You are not authorized to access this page." unless current_user&.super_user?
    end
  end
end
