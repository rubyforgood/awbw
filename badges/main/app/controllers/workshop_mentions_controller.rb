class WorkshopMentionsController < ApplicationController
  def index
    authorize! :workshop_mentions, to: :index?
    @workshops = Workshop.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
