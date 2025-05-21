class Api::V1::ResourcesController < Api::V1::ApiController
  def index
    resource_type = params[:type].constantize
    if resource_type
      @resources = resource_type.all.to_json(include: :related_workshops)
      render json: @resources, status: :ok
    else
      render json: {}, status: :unauthorized
    end
  end
end
