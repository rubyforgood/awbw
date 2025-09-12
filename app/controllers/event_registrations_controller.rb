class EventRegistrationsController < ApplicationController

  def create
    @event_registration = EventRegistration.new(event_registration_params)
    if @event_registration.save
      redirect_to @event_registration.event, notice: 'Successfully registered for the event.'
    else
      redirect_to @event_registration.event, alert: "Registration failed: #{@event_registration.errors.full_messages.join(', ')}"
    end
  end

  def bulk_create
    event_ids = Array(params[:event_ids]).map(&:to_i).uniq
    if event_ids.blank?
      redirect_to events_path, alert: "Please select at least one event."
      return
    end

    attendee_attrs = {
      first_name: current_user.first_name || current_user.email.split('@').first,
      last_name:  current_user.last_name || 'User',
      email:      current_user.email
    }

    created = 0
    errors = []

    Event.transaction do
      event_ids.each do |event_id|
        existing_registration = EventRegistration.where(
          event_id: event_id,
          email: attendee_attrs[:email]
        ).first

        if existing_registration
          errors << "Event '#{Event.find(event_id).title}': You are already registered for this event."
          next
        end

        reg = EventRegistration.new(attendee_attrs.merge(event_id: event_id))
        unless reg.save
          errors << "Event '#{Event.find(event_id).title}': #{reg.errors.full_messages.to_sentence}"
        else
          created += 1
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      redirect_to events_path, alert: errors.join("; ")
    else
      redirect_to events_path, notice: "Successfully registered for #{created} event#{'s' if created != 1}."
    end
  end

  private

  def event_registration_params
    params.require(:event_registration).permit(:event_id, :first_name, :last_name, :email)
  end
end
