module Admin
  class BaseController < ApplicationController
    before_action :authorize_admin_access

    private

    def authorize_admin_access
      authorize! :admin, with: AdminPolicy
    end
  end
end
