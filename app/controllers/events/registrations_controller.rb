module Events
  class RegistrationsController < ApplicationController
    before_action :set_event
    before_action :set_registrant

    def create
      @event_registration = @event.event_registrations.new(registrant: @registrant)
      authorize! @event_registration

      if @event_registration.save
        redirect_to @event_registration, notice: "You have successfully registered for this event."
      else
        error = @event_registration.errors.full_messages.to_sentence
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = error }
          format.html { redirect_to @event, alert: error }
        end
      end
    end

    def destroy
      @event_registration = @event.event_registrations.find_by(registrant: @registrant)

      unless @event_registration
        skip_verify_authorized!
        alert = "Registration not found"
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = alert }
          format.html { redirect_to @event, alert: alert }
        end
        return
      end

      authorize! @event_registration

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

    def set_registrant
      if params[:registrant_id]
        @registrant = Person.find(params[:registrant_id])
      else
        @registrant = current_user.person || create_person_for_current_user
      end
    end

    def create_person_for_current_user
      person = Person.create!(
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        email: current_user.email,
        created_by: current_user,
        updated_by: current_user
      )
      current_user.update!(person: person)
      person
    end
  end
end
