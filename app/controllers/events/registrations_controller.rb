module Events
  class RegistrationsController < ApplicationController
    before_action :set_event, only: [ :create, :destroy ]

    def create
      @event_registration = @event.event_registrations.new(registrant: current_user)
      authorize! :event_registration, to: :create?

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
    #
    # def destroy
    #   registration = @event.event_registrations.find_by(registrant: current_user)
    #   authorize! :event_registration, to: :destroy?
    #
    #   unless registration
    #     return respond_with_alert("Registration not found")
    #   end
    #
    #   if registration.destroy
    #     respond_with_notice("You are no longer registered.")
    #   else
    #     respond_with_alert(registration.errors.full_messages.to_sentence)
    #   end
    # end

    def destroy
      registration = @event.event_registrations.find_by(registrant: current_user)
      authorize! :event_registration, to: :destroy?

      unless registration
        respond_to do |format|
          format.turbo_stream do
            flash.now[:alert] = "Registration not found"
            render turbo_stream: turbo_stream.replace(
              "flash",
              partial: "shared/flash_messages"
            )
          end
          format.html { redirect_to @event, alert: "Registration not found" }
        end
        return
      end

      registration.destroy!

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "You are no longer registered."
          render turbo_stream: turbo_stream.replace(
            "flash",
            partial: "shared/flash_messages"
          )
        end
        format.html { redirect_to @event, notice: "You are no longer registered." }
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
