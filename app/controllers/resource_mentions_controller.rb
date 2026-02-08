class ResourceMentionsController < ApplicationController
  def index
    authorize!
    @resources = Resource.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
