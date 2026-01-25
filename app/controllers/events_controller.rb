class EventsController < ApplicationController
  include AhoyViewTracking
  before_action :set_event, only: %i[ show edit update destroy ]

  def index
    unpaginated = authorized_scope(Event).search_by_params(params)
    @events = unpaginated.order(start_date: :desc)
  end

  def show
    @event = @event.decorate
    track_view(@event)
  end

  def new # all logged in users can create events
    @event = Event.new.decorate
    set_form_variables
  end

  def edit
    authorize! @event, to: :update?
    set_form_variables
  end

  def create
    @event = Event.new(event_params).decorate
    @event.created_by ||= current_user

    respond_to do |format|
      if @event.save
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
    authorize! @event, to: :update?
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
    authorize! @event, to: :destroy?
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
                                  :publicly_visible,
                                  primary_asset_attributes: [ :id, :file, :_destroy ],
                                  gallery_assets_attributes: [ :id, :file, :_destroy ]
                                  )
  end
end
