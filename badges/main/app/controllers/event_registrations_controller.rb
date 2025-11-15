class EventRegistrationsController < ApplicationController
  before_action :set_event, only: [:create, :destroy]
  before_action :set_event_registration, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = EventRegistration.search_by_params(params)
    @event_registrations_count = unpaginated.count
    @event_registrations = unpaginated.paginate(page: params[:page], per_page: per_page)
  end

  def show
  end

  def new
    @event_registration = EventRegistration.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    if @event
    	@event_registration = @event.event_registrations.new(registrant: current_user)
		else
      @event_registration = EventRegistration.new(event_registration_params)
		end

    if @event_registration.save
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "You have successfully registered for this event." }
        format.html { redirect_to event_registrations_path,
                                  notice: "You have successfully registered for this event." }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:alert] = @event_registration.errors.full_messages.to_sentence }
        format.html { redirect_to event_registrations_path,
                                  alert: @event_registration.errors.full_messages.to_sentence }
      end
    end
  end


  def update
    if @event_registration.update(event_registration_params)
      redirect_to event_registrations_path, notice: "Banner was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end


  def destroy
    if @event
      @event_registration ||= @event.event_registrations.find_by(registrant: current_user)
    end

    if @event_registration
      @event_registration.destroy

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "You are no longer registered."
          render turbo_stream: turbo_stream.remove(dom_id(@event_registration))
        end

        format.html do
          flash[:notice] = "You are no longer registered."
          redirect_to event_registrations_path
        end
      end

    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Unable to find that registration."
        end

        format.html do
          flash[:alert] = "Unable to find that registration."
          redirect_to event_registrations_path
        end
      end
    end
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @events = Event.publicly_visible.order(:start_date)
    @registrants = User.active.order(:last_name, :first_name)
  end

  private

  def set_event_registration
    @event_registration = EventRegistration.find(params[:id])
  end

  def set_event
    @event = Event.find(params[:event_id]) if params[:event_id].present?
  end

  # Strong parameters
  def event_registration_params
    params.require(:event_registration).permit(
      :event_id, :registrant_id
    )
  end
end
