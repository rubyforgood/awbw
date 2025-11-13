class EventRegistrationsController < ApplicationController
  before_action :set_event, only: [:create, :destroy]

  def create
    @event_registration = @event.event_registrations.new(registrant: current_user)

    if @event_registration.save
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "You have successfully registered for this event." }
        format.html { redirect_to @event, notice: "You have successfully registered for this event." }
      end
    else
      respond_to do |format|
        format.tubo_stream { flash.now[:alert] = @event_registration.errors.full_messages.to_sentence }
        format.html { redirect_to @event, alert: @event_registration.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    @event_registration = @event.event_registrations.find_by(registrant: current_user)
    if @event_registration
      @event_registration.destroy
      flash[:notice] = "You are no longer registered."
      redirect_to events_path
    else
      flash[:alert] = "Unable to find that registration."
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
