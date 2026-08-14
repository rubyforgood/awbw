module Api
  # Base for the JSON API. Renders errors as JSON rather than the HTML redirects
  # ApplicationController uses. Authentication stays on by default — public
  # endpoints opt out with `skip_before_action :authenticate_user!` themselves.
  class BaseController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from ActionPolicy::Unauthorized do
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
