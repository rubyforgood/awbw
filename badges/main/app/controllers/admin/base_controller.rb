module Admin
	class BaseController < ApplicationController
		before_action :require_super_user

		private

		def require_super_user
			redirect_to authenticated_root_path, alert: "Not authorized" unless current_user&.super_user?
		end
	end
end
