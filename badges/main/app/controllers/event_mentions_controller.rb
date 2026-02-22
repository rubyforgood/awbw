class EventMentionsController < ApplicationController
  skip_verify_authorized
  def index
    @events = Event.where(id: params[:query])
    respond_to do |format|
      format.json
    end
  end
end
