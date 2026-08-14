module Api
  # Base for the public, read-only JSON API. These endpoints serve only
  # unconditionally public data, so authentication is skipped and errors are
  # rendered as JSON rather than the HTML redirects ApplicationController uses.
  class BaseController < ApplicationController
    skip_before_action :authenticate_user!

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from ActionPolicy::Unauthorized do
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
