class EventsController < ApplicationController
  include AhoyTracking, AssetUpdatable
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_event, only: %i[ show edit update destroy ]

  def index
    authorize!
    base_scope = authorized_scope(Event.all)
    @events  = base_scope.search_by_params(params).order(start_date: :desc)
  end

  def show
    authorize! @event
    @event = @event.decorate
    track_view(@event)
  end

  def new
    authorize!
    @event = Event.new.decorate
    set_form_variables
  end

  def edit
    authorize! @event
    set_form_variables
    unless @event.created_by == current_user || current_user.super_user?
      redirect_to events_path, alert: "You are not authorized to edit this event."
    end
  end

  def create
    authorize!
    @event = Event.new(event_params).decorate
    @event.created_by ||= current_user

    respond_to do |format|
      if @event.save
        if params.dig(:library_asset, :new_assets).present?
          update_asset_owner(@event)
        end
        format.html { redirect_to events_path, notice: "Event was successfully created." }
        format.json { render :show, status: :created, location: @event }
      else
        set_form_variables
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    authorize! @event
    respond_to do |format|
      if @event.update(event_params)
        format.html { redirect_to events_path, notice: "Event was successfully updated." }
        format.json { render :show, status: :ok, location: @event }
      else
        set_form_variables
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @event.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    authorize! @event
    @event.destroy

    respond_to do |format|
      format.html { redirect_to events_path, status: :see_other, notice: "Event was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_form_variables
    @event = @event.decorate
    @event.build_primary_asset if @event.primary_asset.blank?
    @event.gallery_assets.build
  end

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:cost,
                                  :created_by_id,
                                  :title,
                                  :description,
                                  :featured,
                                  :start_date, :end_date,
                                  :registration_close_date,
                                  :published,
                                  :publicly_visible,
                                  :publicly_featured
                                  )
  end
end
