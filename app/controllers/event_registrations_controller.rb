class EventRegistrationsController < ApplicationController
  before_action :set_event, only: [:create, :destroy]

  def create
    @event_registration = @event.event_registrations.new(user: current_user)

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
    @event_registration = @event.event_registrations.find_by(user: current_user)
    if @event_registration
      @event_registration.destroy
      flash[:notice] = "You are no longer registered."
      redirect_to events_path
    else
      flash[:alert] = "Unable to find that registration."
    end
  end
  # def bulk_create
  #   event_ids = Array(params[:event_ids]).map(&:to_i).uniq
  #   if event_ids.blank?
  #     redirect_to events_path, alert: "Please select at least one event."
  #     return
  #   end
  #
  #   attendee_attrs = {
  #     first_name: current_user.first_name || current_user.email.split("@").first,
  #     last_name: current_user.last_name || "User",
  #     email: current_user.email
  #   }
  #
  #   created = 0
  #   errors = []
  #
  #   Event.transaction do
  #     event_ids.each do |event_id|
  #       existing_registration = EventRegistration.where(
  #         event_id: event_id,
  #         email: attendee_attrs[:email]
  #       ).first
  #
  #       if existing_registration
  #         errors << "Event '#{Event.find(event_id).title}': You are already registered for this event."
  #         next
  #       end
  #
  #       reg = EventRegistration.new(attendee_attrs.merge(event_id: event_id))
  #       if reg.save
  #         created += 1
  #       else
  #         errors << "Event '#{Event.find(event_id).title}': #{reg.errors.full_messages.to_sentence}"
  #       end
  #     end
  #
  #      raise ActiveRecord::Rollback if errors.any?
  #   end
  #
  #   if errors.any?
  #     redirect_to events_path, alert: errors.join("; ")
  #   else
  #     redirect_to events_path, notice: "Successfully registered for #{created} event#{"s" if created != 1}."
  #   end
  # end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
