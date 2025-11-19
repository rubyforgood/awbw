class EventsController < ApplicationController
  before_action :set_event, only: %i[ show edit update destroy ]
  before_action :authorize_admin!, only: %i[ edit update destroy ]

  def index
    @events = Event.order(start_date: :desc)
    @events = @events.publicly_visible unless current_user.super_user?
  end

  def show
  end

  def new # all logged in users can create events
    @event = Event.new
  end

  def edit
    unless @event.created_by == current_user || current_user.super_user?
      redirect_to events_path, alert: "You are not authorized to edit this event."
    end
  end

  def create
    @event = Event.new(event_params)
    @event.created_by ||= current_user

    respond_to do |format|
      if @event.save
        format.html { redirect_to events_path, notice: "Event was successfully created." }
        format.json { render :show, status: :created, location: @event }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @event.update(event_params)
        format.html { redirect_to events_path, notice: "Event was successfully updated." }
        format.json { render :show, status: :ok, location: @event }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_path, status: :see_other, notice: "Event was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:created_by_id,
                                  :title,
                                  :description,
                                  :featured,
                                  :start_date, :end_date,
                                  :registration_close_date,
                                  :publicly_visible)
  end

  def authorize_admin!
    redirect_to events_path, alert: "You are not authorized to perform this action." unless current_user.super_user?
  end
end
