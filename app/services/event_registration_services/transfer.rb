module EventRegistrationServices
  # Moves a registrant from one event to another by creating a new registration
  # on the destination event linked back to the original, and marking the
  # original as "transferred". The payment/allocations stay on the original; the
  # new registration shows a "Previous reg" payment status (fee covered
  # by the prior payment), so nothing is owed on the destination event.
  class Transfer
    Result = Struct.new(:registration, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(source:, target_event_id:, current_user: nil)
      new(source:, target_event_id:, current_user:).call
    end

    def initialize(source:, target_event_id:, current_user: nil)
      @source = source
      @target_event_id = target_event_id
      @current_user = current_user
    end

    def call
      target_event = Event.find_by(id: @target_event_id)
      return Result.new(error: "Choose an event to transfer to.") if target_event.nil?
      return Result.new(error: "Choose a different event than the current one.") if target_event.id == @source.event_id

      if EventRegistration.exists?(registrant_id: @source.registrant_id, event_id: target_event.id)
        return Result.new(error: "#{@source.registrant.full_name} is already registered for #{target_event.title}.")
      end

      new_registration = nil
      ApplicationRecord.transaction do
        new_registration = EventRegistration.create!(
          registrant: @source.registrant,
          event: target_event,
          status: "registered",
          transferred_from: @source
        )
        @source.update!(status: "transferred")
      end

      Result.new(registration: new_registration)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(error: e.record.errors.full_messages.to_sentence)
    rescue ActiveRecord::RecordNotUnique
      Result.new(error: "#{@source.registrant.full_name} is already registered for that event.")
    end
  end
end
