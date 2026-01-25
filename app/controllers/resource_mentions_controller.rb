class ResourceMentionsController < ApplicationController
  def index
    base_scope = authorized_scope(Resource, with: ResourceMentionPolicy)
    @resources = base_scope.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
