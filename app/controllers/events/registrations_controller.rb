module Events
  class RegistrationsController < ApplicationController
    before_action :authenticate_user!, only: [ :create, :destroy ]
    before_action :set_event, only: [ :create, :destroy ]
    before_action :set_registrant, only: [ :create, :destroy ]
    before_action :set_event_registration, only: [ :show, :resend_confirmation, :cancel, :reactivate ]

    def show
      authorize! @event_registration, to: :show_public?
    end

    def resend_confirmation
      authorize! @event_registration, to: :show_public?
      EventMailer.event_registration_confirmation(@event_registration).deliver_later
      redirect_to registration_ticket_path(@event_registration.slug), notice: "Confirmation email sent."
    end

    def cancel
      authorize! @event_registration, to: :show_public?

      if @event_registration.active?
        @event_registration.update!(status: "cancelled")
        redirect_to registration_ticket_path(@event_registration.slug), notice: "Your registration has been cancelled."
      else
        redirect_to registration_ticket_path(@event_registration.slug), alert: "Registration is already cancelled."
      end
    end

    def reactivate
      authorize! @event_registration, to: :show_public?

      if @event_registration.status == "cancelled"
        @event_registration.update!(status: "registered")
        redirect_to registration_ticket_path(@event_registration.slug), notice: "Your registration has been reactivated."
      else
        redirect_to registration_ticket_path(@event_registration.slug), alert: "Registration is not cancelled."
      end
    end

    def create
      existing = @event.event_registrations.find_by(registrant: @registrant)

      if existing&.status == "cancelled"
        authorize! existing
        existing.update!(status: "registered")
        success = "Your registration has been reactivated."
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = success }
          format.html { redirect_to registration_ticket_path(existing.slug), notice: success }
        end
        return
      end

      @event_registration = @event.event_registrations.new(registrant: @registrant)
      authorize! @event_registration

      if @event_registration.save
        success = "You have successfully registered for this event."
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = success }
          format.html { redirect_to registration_ticket_path(@event_registration.slug), notice: success }
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

    def set_event_registration
      @event_registration = EventRegistration.find_by!(slug: params[:slug])
    end
  end
end
