class EventRegistrationsController < ApplicationController
  before_action :set_event_registration, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = EventRegistration.search_by_params(params)
    @event_registrations_count = unpaginated.size
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
    @event_registration = EventRegistration.new(event_registration_params)

    if @event_registration.save
      respond_to do |format|
        format.html {
          redirect_to event_registrations_path,
            notice: "Registration created."
        }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to event_registrations_path,
            alert: @event_registration.errors.full_messages.to_sentence
        }
      end
    end
  end

  def update
    if @event_registration.update(event_registration_params)
      redirect_to event_registrations_path, notice: "Registration was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @event_registration.destroy
      flash[:notice] = "Registration deleted."

    else
      flash[:alert] = @event_registration.errors.full_messages.to_sentence
    end
    redirect_to event_registrations_path
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

  # Strong parameters
  def event_registration_params
    params.require(:event_registration).permit(
      :event_id, :registrant_id
    )
  end
end
