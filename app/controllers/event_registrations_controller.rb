class EventRegistrationsController < ApplicationController
  def create
    @event_registration = EventRegistration.new(event_registration_params)
    if @event_registration.save
      redirect_to @event_registration.event, notice: 'Successfully registered for the event.'
    else
      render :new
    end
  end

  private

  def event_registration_params
    params.require(:event_registration).permit(:event_id, :user_id)
  end
end