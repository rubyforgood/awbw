module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private

    def require_admin
      redirect_to root_path, alert: "Not authorized" unless current_user&.super_user?
    end
  end
end
