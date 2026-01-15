class WorkshopMentionsController < ApplicationController
  def index
    @workshops = Workshop.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
