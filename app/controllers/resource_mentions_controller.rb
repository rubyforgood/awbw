class ResourceMentionsController < ApplicationController
  def index
    @resources = Resource.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
