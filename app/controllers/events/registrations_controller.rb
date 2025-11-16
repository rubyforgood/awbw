module Events
  class RegistrationsController < ApplicationController
    before_action :set_event, only: [:create, :destroy]

    def create
      @event_registration = @event.event_registrations.new(registrant: current_user)

      if @event_registration.save
        success = "You have successfully registered for this event."
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = success }
          format.html { redirect_to @event, notice: success }
        end
      else
        error = @event_registration.errors.full_messages.to_sentence
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = error }
          format.html { redirect_to @event, alert: error }
        end
      end
    end

    def destroy
      @event_registration = @event.event_registrations.find_by(registrant: current_user)

      unless @event_registration
        alert = "Registration not found"
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = alert }
          format.html { redirect_to @event, alert: alert }
        end
        return
      end

      if @event_registration.destroy
        success = "You are no longer registered."
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = success }
          format.html { redirect_to @event, notice: success }
        end
      else
        error = @event_registration.errors.full_messages.to_sentence
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = error }
          format.html { redirect_to @event, alert: error }
        end
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
