class WorkshopMentionsController < ApplicationController
  def index
    base_scope = authorized_scope(Workshop, with: WorkshopMentionPolicy)
    @workshops = base_scope.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
