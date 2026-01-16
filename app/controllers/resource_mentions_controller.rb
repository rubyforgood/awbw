class ResourceMentionsController < ApplicationController
  def index
    # TODO add action_policy scope for super_user
    @resources = Resource.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
